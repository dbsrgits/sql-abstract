package SQL::Abstract::Test; # see doc at end of file

use strict;
use warnings;
use base qw/Test::Builder::Module Exporter/;
use Data::Dumper;
use Carp;
use Test::Builder;
use Test::Deep qw(eq_deeply);

our @EXPORT_OK = qw/&is_same_sql_bind &is_same_sql &is_same_bind
                    &eq_sql_bind &eq_sql &eq_bind 
                    $case_sensitive $sql_differ/;

our $case_sensitive = 0;
our $sql_differ; # keeps track of differing portion between SQLs
our $tb = __PACKAGE__->builder;

# Parser states for _recurse_parse()
use constant PARSE_TOP_LEVEL => 0;
use constant PARSE_IN_EXPR => 1;
use constant PARSE_IN_PARENS => 2;

# These SQL keywords always signal end of the current expression (except inside
# of a parenthesized subexpression).
# Format: A list of strings that will be compiled to extended syntax (ie.
# /.../x) regexes, without capturing parentheses. They will be automatically
# anchored to word boundaries to match the whole token).
my @expression_terminator_sql_keywords = (
  'FROM',
  '(?:
    (?:
        (?: \b (?: LEFT | RIGHT | FULL ) \s+ )?
        (?: \b (?: CROSS | INNER | OUTER ) \s+ )?
    )?
    JOIN
  )',
  'ON',
  'WHERE',
  'GROUP \s+ BY',
  'HAVING',
  'ORDER \s+ BY',
  'LIMIT',
  'OFFSET',
  'FOR',
  'UNION',
  'INTERSECT',
  'EXCEPT',
);

my $tokenizer_re_str = join('|',
  map { '\b' . $_ . '\b' }
    @expression_terminator_sql_keywords, 'AND', 'OR'
);

my $tokenizer_re = qr/
  \s*
  (
      \(
    |
      \)
    |
      $tokenizer_re_str
  )
  \s*
/xi;


sub is_same_sql_bind {
  my ($sql1, $bind_ref1, $sql2, $bind_ref2, $msg) = @_;

  # compare
  my $same_sql  = eq_sql($sql1, $sql2);
  my $same_bind = eq_bind($bind_ref1, $bind_ref2);

  # call Test::Builder::ok
  my $ret = $tb->ok($same_sql && $same_bind, $msg);

  # add debugging info
  if (!$same_sql) {
    _sql_differ_diag($sql1, $sql2);
  }
  if (!$same_bind) {
    _bind_differ_diag($bind_ref1, $bind_ref2);
  }

  # pass ok() result further
  return $ret;
}

sub is_same_sql {
  my ($sql1, $sql2, $msg) = @_;

  # compare
  my $same_sql  = eq_sql($sql1, $sql2);

  # call Test::Builder::ok
  my $ret = $tb->ok($same_sql, $msg);

  # add debugging info
  if (!$same_sql) {
    _sql_differ_diag($sql1, $sql2);
  }

  # pass ok() result further
  return $ret;
}

sub is_same_bind {
  my ($bind_ref1, $bind_ref2, $msg) = @_;

  # compare
  my $same_bind = eq_bind($bind_ref1, $bind_ref2);

  # call Test::Builder::ok
  my $ret = $tb->ok($same_bind, $msg);

  # add debugging info
  if (!$same_bind) {
    _bind_differ_diag($bind_ref1, $bind_ref2);
  }

  # pass ok() result further
  return $ret;
}

sub _sql_differ_diag {
  my ($sql1, $sql2) = @_;

  $tb->diag("SQL expressions differ\n"
      ."     got: $sql1\n"
      ."expected: $sql2\n"
      ."differing in :\n$sql_differ\n"
      );
}

sub _bind_differ_diag {
  my ($bind_ref1, $bind_ref2) = @_;

  $tb->diag("BIND values differ\n"
      ."     got: " . Dumper($bind_ref1)
      ."expected: " . Dumper($bind_ref2)
      );
}

sub eq_sql_bind {
  my ($sql1, $bind_ref1, $sql2, $bind_ref2) = @_;

  return eq_sql($sql1, $sql2) && eq_bind($bind_ref1, $bind_ref2);
}


sub eq_bind {
  my ($bind_ref1, $bind_ref2) = @_;

  return eq_deeply($bind_ref1, $bind_ref2);
}

sub eq_sql {
  my ($sql1, $sql2) = @_;

  # parse
  my $tree1 = parse($sql1);
  my $tree2 = parse($sql2);

  return _eq_sql($tree1, $tree2);
}

sub _eq_sql {
  my ($left, $right) = @_;

  # ignore top-level parentheses 
  while ($left and $left->[0] and $left->[0]  eq 'PAREN') {$left  = $left->[1]}
  while ($right and $right->[0] and $right->[0] eq 'PAREN') {$right = $right->[1]}

  # one is defined the other not
  if ( (defined $left) xor (defined $right) ) {
    return 0;
  }
  # one is undefined, then so is the other
  elsif (not defined $left) {
    return 1;
  }
  # if operators are different
  elsif ($left->[0] ne $right->[0]) {
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
      return _eq_sql($left->[1][0], $right->[1][0])  # left operand
          && _eq_sql($left->[1][1], $right->[1][1]); # right operand
    }
  }
}


sub parse {
  my $s = shift;

  # tokenize string, and remove all optional whitespace
  my $tokens = [];
  foreach my $token (split $tokenizer_re, $s) {
    $token =~ s/\s+/ /g;
    $token =~ s/\s+([^\w\s])/$1/g;
    $token =~ s/([^\w\s])\s+/$1/g;
    push @$tokens, $token if $token !~ /^$/;
  }

  my $tree = _recurse_parse($tokens, PARSE_TOP_LEVEL);
  return $tree;
}

sub _recurse_parse {
  my ($tokens, $state) = @_;

  my $left;
  while (1) { # left-associative parsing

    my $lookahead = $tokens->[0];
    return $left if !defined($lookahead)
      || ($state == PARSE_IN_PARENS && $lookahead eq ')')
      || ($state == PARSE_IN_EXPR && grep { $lookahead =~ /^$_$/xi }
            '\)', @expression_terminator_sql_keywords
         );

    my $token = shift @$tokens;

    # nested expression in ()
    if ($token eq '(') {
      my $right = _recurse_parse($tokens, PARSE_IN_PARENS);
      $token = shift @$tokens   or croak "missing ')'";
      $token eq ')'             or croak "unexpected token : $token";
      $left = $left ? [CONCAT => [$left, [PAREN => $right]]]
                    : [PAREN  => $right];
    }
    # AND/OR
    elsif ($token eq 'AND' || $token eq 'OR')  {
      my $right = _recurse_parse($tokens, PARSE_IN_EXPR);
      $left = [$token => [$left, $right]];
    }
    # expression terminator keywords (as they start a new expression)
    elsif (grep { $token =~ /^$_$/xi } @expression_terminator_sql_keywords) {
      my $right = _recurse_parse($tokens, PARSE_IN_EXPR);
      $left = $left ? [CONCAT => [$left, [CONCAT => [[EXPR => $token], [PAREN => $right]]]]]
                    : [CONCAT => [[EXPR => $token], [PAREN  => $right]]];
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
  use SQL::Abstract::Test import => [qw/
    is_same_sql_bind is_same_sql is_same_bind
    eq_sql_bind eq_sql eq_bind
  /];
  
  my ($sql, @bind) = SQL::Abstract->new->select(%args);

  is_same_sql_bind($given_sql,    \@given_bind, 
                   $expected_sql, \@expected_bind, $test_msg);

  is_same_sql($given_sql, $expected_sql, $test_msg);
  is_same_bind(\@given_bind, \@expected_bind, $test_msg);

  my $is_same = eq_sql_bind($given_sql,    \@given_bind, 
                            $expected_sql, \@expected_bind);

  my $sql_same = eq_sql($given_sql, $expected_sql);
  my $bind_same = eq_bind(\@given_bind, \@expected_bind);

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
L<Test::Builder/ok> on the result, with C<$test_msg> as message. If the test
fails, a detailed diagnostic is printed. For clients which use L<Test::More>,
this is the one of the three functions (L</is_same_sql_bind>, L</is_same_sql>,
L</is_same_bind>) that needs to be imported.

=head2 is_same_sql

  is_same_sql($given_sql, $expected_sql, $test_msg);

Compares given and expected SQL statements, and calls L<Test::Builder/ok> on
the result, with C<$test_msg> as message. If the test fails, a detailed
diagnostic is printed. For clients which use L<Test::More>, this is the one of
the three functions (L</is_same_sql_bind>, L</is_same_sql>, L</is_same_bind>)
that needs to be imported.

=head2 is_same_bind

  is_same_bind(\@given_bind, \@expected_bind, $test_msg);

Compares given and expected bind values, and calls L<Test::Builder/ok> on the
result, with C<$test_msg> as message. If the test fails, a detailed diagnostic
is printed. For clients which use L<Test::More>, this is the one of the three
functions (L</is_same_sql_bind>, L</is_same_sql>, L</is_same_bind>) that needs
to be imported.

=head2 eq_sql_bind

  my $is_same = eq_sql_bind($given_sql,    \@given_bind, 
                            $expected_sql, \@expected_bind);

Compares given and expected pairs of C<($sql, \@bind)>. Similar to
L</is_same_sql_bind>, but it just returns a boolean value and does not print
diagnostics or talk to L<Test::Builder>.

=head2 eq_sql

  my $is_same = eq_sql($given_sql, $expected_sql);

Compares the abstract syntax of two SQL statements. Similar to L</is_same_sql>,
but it just returns a boolean value and does not print diagnostics or talk to
L<Test::Builder>. If the result is false, the global variable L</$sql_differ>
will contain the SQL portion where a difference was encountered; this is useful
for printing diagnostics.

=head2 eq_bind

  my $is_same = eq_sql(\@given_bind, \@expected_bind);

Compares two lists of bind values, taking into account the fact that some of
the values may be arrayrefs (see L<SQL::Abstract/bindtype>). Similar to
L</is_same_bind>, but it just returns a boolean value and does not print
diagnostics or talk to L<Test::Builder>.

=head1 GLOBAL VARIABLES

=head2 $case_sensitive

If true, SQL comparisons will be case-sensitive. Default is false;

=head2 $sql_differ

When L</eq_sql> returns false, the global variable
C<$sql_differ> contains the SQL portion
where a difference was encountered.


=head1 SEE ALSO

L<SQL::Abstract>, L<Test::More>, L<Test::Builder>.

=head1 AUTHORS

Laurent Dami, E<lt>laurent.dami AT etat  geneve  chE<gt>

Norbert Buchmuller <norbi@nix.hu>

=head1 COPYRIGHT AND LICENSE

Copyright 2008 by Laurent Dami.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
