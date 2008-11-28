package SQL::Abstract::Test; # see doc at end of file

use strict;
use warnings;
use base qw/Test::Builder::Module Exporter/;
use Scalar::Util qw(looks_like_number blessed reftype);
use Data::Dumper;
use Carp;
use Test::Builder;
use Test::Deep qw(eq_deeply);

our @EXPORT_OK = qw/&is_same_sql_bind &eq_sql &eq_bind 
                    $case_sensitive $sql_differ/;

our $case_sensitive = 0;
our $sql_differ; # keeps track of differing portion between SQLs
our $tb = __PACKAGE__->builder;

sub is_same_sql_bind {
  my ($sql1, $bind_ref1, $sql2, $bind_ref2, $msg) = @_;

  # compare
  my $tree1     = parse($sql1);
  my $tree2     = parse($sql2);
  my $same_sql  = eq_sql($tree1, $tree2);
  my $same_bind = eq_bind($bind_ref1, $bind_ref2);

  # call Test::Builder::ok
  $tb->ok($same_sql && $same_bind, $msg);

  # add debugging info
  if (!$same_sql) {
    $tb->diag("SQL expressions differ\n"
        ."     got: $sql1\n"
        ."expected: $sql2\n"
        ."differing in :\n$sql_differ\n"
        );
  }
  if (!$same_bind) {
    $tb->diag("BIND values differ\n"
        ."     got: " . Dumper($bind_ref1)
        ."expected: " . Dumper($bind_ref2)
        );
  }
}

sub eq_bind {
  my ($bind_ref1, $bind_ref2) = @_;

  return eq_deeply($bind_ref1, $bind_ref2);
}

sub eq_sql {
  my ($left, $right) = @_;

  # ignore top-level parentheses 
  while ($left->[0]  eq 'PAREN') {$left  = $left->[1] }
  while ($right->[0] eq 'PAREN') {$right = $right->[1]}

  # if operators are different
  if ($left->[0] ne $right->[0]) { 
    $sql_differ = sprintf "OP [$left->[0]] != [$right->[0]] in\nleft: %s\nright: %s\n",
      unparse($left),
      unparse($right);
    return 0;
  }
  # elsif operators are identical, compare operands
  else { 
    if ($left->[0] eq 'EXPR' ) { # unary operator
      (my $l = " $left->[1] " ) =~ s/\s+/ /g;
      (my $r = " $right->[1] ") =~ s/\s+/ /g;
      my $eq = $case_sensitive ? $l eq $r : uc($l) eq uc($r);
      $sql_differ = "[$left->[1]] != [$right->[1]]\n" if not $eq;
      return $eq;
    }
    else { # binary operator
      return eq_sql($left->[1][0], $right->[1][0])  # left operand
          && eq_sql($left->[1][1], $right->[1][1]); # right operand
    }
  }
}


sub parse {
  my $s = shift;

  # tokenize string
  my $tokens = [grep {!/^\s*$/} split /\s*(\(|\)|\bAND\b|\bOR\b)\s*/, $s];

  my $tree = _recurse_parse($tokens);
  return $tree;
}

sub _recurse_parse {
  my $tokens = shift;

  my $left;
  while (1) { # left-associative parsing

    my $lookahead = $tokens->[0];
    return $left if !defined($lookahead) || $lookahead eq ')';

    my $token = shift @$tokens;

    # nested expression in ()
    if ($token eq '(') {
      my $right = _recurse_parse($tokens);
      $token = shift @$tokens   or croak "missing ')'";
      $token eq ')'             or croak "unexpected token : $token";
      $left = $left ? [CONCAT => [$left, [PAREN => $right]]]
                    : [PAREN  => $right];
    }
    # AND/OR
    elsif ($token eq 'AND' || $token eq 'OR')  {
      my $right = _recurse_parse($tokens);
      $left = [$token => [$left, $right]];
    }
    # leaf expression
    else {
      $left = $left ? [CONCAT => [$left, [EXPR => $token]]]
                    : [EXPR   => $token];
    }
  }
}



sub unparse {
  my $tree = shift;
  my $dispatch = {
    EXPR   => sub {$tree->[1]                                   },
    PAREN  => sub {"(" . unparse($tree->[1]) . ")"              },
    CONCAT => sub {join " ",     map {unparse($_)} @{$tree->[1]}},
    AND    => sub {join " AND ", map {unparse($_)} @{$tree->[1]}},
    OR     => sub {join " OR ",  map {unparse($_)} @{$tree->[1]}},
   };
  $dispatch->{$tree->[0]}->();
}


1;


__END__

=head1 NAME

SQL::Abstract::Test - Helper function for testing SQL::Abstract

=head1 SYNOPSIS

  use SQL::Abstract;
  use Test::More;
  use SQL::Abstract::Test import => ['is_same_sql_bind'];
  
  my ($sql, @bind) = SQL::Abstract->new->select(%args);
  is_same_sql_bind($given_sql,    \@given_bind, 
                   $expected_sql, \@expected_bind, $test_msg);

=head1 DESCRIPTION

This module is only intended for authors of tests on
L<SQL::Abstract|SQL::Abstract> and related modules;
it exports functions for comparing two SQL statements
and their bound values.

The SQL comparison is performed on I<abstract syntax>,
ignoring differences in spaces or in levels of parentheses.
Therefore the tests will pass as long as the semantics
is preserved, even if the surface syntax has changed.

B<Disclaimer> : this is only a half-cooked semantic equivalence;
parsing is simple-minded, and comparison of SQL abstract syntax trees
ignores commutativity or associativity of AND/OR operators, Morgan
laws, etc.

=head1 FUNCTIONS

=head2 is_same_sql_bind

  is_same_sql_bind($given_sql,    \@given_bind, 
                   $expected_sql, \@expected_bind, $test_msg);

Compares given and expected pairs of C<($sql, \@bind)>, and calls
L<Test::Builder/ok> on the result, with C<$test_msg> as message. If the
test fails, a detailed diagnostic is printed. For clients which use
L<Test::Build>, this is the only function that needs to be
imported.

=head2 eq_sql

  my $is_same = eq_sql($given_sql, $expected_sql);

Compares the abstract syntax of two SQL statements.  If the result is
false, global variable L</sql_differ> will contain the SQL portion
where a difference was encountered; this is useful for printing diagnostics.

=head2 eq_bind

  my $is_same = eq_sql(\@given_bind, \@expected_bind);

Compares two lists of bind values, taking into account
the fact that some of the values may be
arrayrefs (see L<SQL::Abstract/bindtype>).

=head1 GLOBAL VARIABLES

=head2 case_sensitive

If true, SQL comparisons will be case-sensitive. Default is false;

=head2 sql_differ

When L</eq_sql> returns false, the global variable
C<$sql_differ> contains the SQL portion
where a difference was encountered.


=head1 SEE ALSO

L<SQL::Abstract>, L<Test::More>, L<Test::Builder>.

=head1 AUTHOR

Laurent Dami, E<lt>laurent.dami AT etat  geneve  chE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
