package TestSqlAbstract;

# compares two SQL expressions on their abstract syntax,
# ignoring differences in levels of parentheses.

use strict;
use warnings;
use Test::More;
use base 'Exporter';
use Data::Dumper;

our @EXPORT = qw/is_same_sql_bind/;


my $last_differ;

sub is_same_sql_bind {
  my ($sql1, $bind_ref1, $sql2, $bind_ref2, $msg) = @_;

  my $tree1     = parse($sql1);
  my $tree2     = parse($sql2);
  my $same_sql  = eq_tree($tree1, $tree2);
  my $same_bind = stringify_bind($bind_ref1) eq stringify_bind($bind_ref2);
  ok($same_sql && $same_bind, $msg);
  if (!$same_sql) {
    diag "SQL expressions differ\n"
        ."     got: $sql1\n"
        ."expected: $sql2\n"
        ."differing in :\n$last_differ\n";
        ;
  }
  if (!$same_bind) {
    diag "BIND values differ\n"
        ."     got: " . Dumper($bind_ref1)
        ."expected: " . Dumper($bind_ref2)
        ;
  }
}

sub stringify_bind {
  my $bind_ref = shift || [];
  return join "///", map {ref $_ ? join('=>', @$_) : ($_ || '')} 
                         @$bind_ref;
}



sub eq_tree {
  my ($left, $right) = @_;

  # ignore top-level parentheses 
  while ($left->[0]  eq 'PAREN') {$left  = $left->[1] }
  while ($right->[0] eq 'PAREN') {$right = $right->[1]}

  if ($left->[0] ne $right->[0]) { # if operators are different
    $last_differ = sprintf "OP [$left->[0]] != [$right->[0]] in\nleft: %s\nright: %s\n",
      unparse($left),
      unparse($right);
    return 0;
  }
  else { # else compare operands
    if ($left->[0] eq 'EXPR' ) {
      if ($left->[1] ne $right->[1]) {
        $last_differ = "[$left->[1]] != [$right->[1]]\n";
        return 0;
      }
      else {
        return 1;
      }
    }
    else {
      my $eq_left  = eq_tree($left->[1][0], $right->[1][0]);
      my $eq_right = eq_tree($left->[1][1], $right->[1][1]);
      return $eq_left && $eq_right;
    }
  }
}


my @tokens;

sub parse {
  my $s = shift;

  # tokenize string
  @tokens = grep {!/^\s*$/} split /\s*(\(|\)|\bAND\b|\bOR\b)\s*/, $s;

  my $tree = _recurse_parse();
  return $tree;
}

sub _recurse_parse {

  my $left;
  while (1) {

    my $lookahead = $tokens[0];
    return $left if !defined($lookahead) || $lookahead eq ')';

    my $token = shift @tokens;

    if ($token eq '(') {
      my $right = _recurse_parse();
      $token = shift @tokens 
        or die "missing ')'";
      $token eq ')' 
        or die "unexpected token : $token";
      $left = $left ? [CONCAT => [$left, [PAREN => $right]]]
                    : [PAREN  => $right];
    }
    elsif ($token eq 'AND' || $token eq 'OR')  {
      my $right = _recurse_parse();
      $left = [$token => [$left, $right]];
    }
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
