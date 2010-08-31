package SQL::Abstract::Tree;

use strict;
use warnings;
use Carp;

# Parser states for _recurse_parse()
use constant PARSE_TOP_LEVEL => 0;
use constant PARSE_IN_EXPR => 1;
use constant PARSE_IN_PARENS => 2;
use constant PARSE_RHS => 3;

# These SQL keywords always signal end of the current expression (except inside
# of a parenthesized subexpression).
# Format: A list of strings that will be compiled to extended syntax (ie.
# /.../x) regexes, without capturing parentheses. They will be automatically
# anchored to word boundaries to match the whole token).
my @expression_terminator_sql_keywords = (
  'SELECT',
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
  'EXISTS',
  'GROUP \s+ BY',
  'HAVING',
  'ORDER \s+ BY',
  'LIMIT',
  'OFFSET',
  'FOR',
  'UNION',
  'INTERSECT',
  'EXCEPT',
  'RETURNING',
);

# These are binary operator keywords always a single LHS and RHS
# * AND/OR are handled separately as they are N-ary
# * so is NOT as being unary
# * BETWEEN without paranthesis around the ANDed arguments (which
#   makes it a non-binary op) is detected and accomodated in
#   _recurse_parse()
my $stuff_around_mathops = qr/[\w\s\`\'\"\)]/;
my @binary_op_keywords = (
  ( map
    {
      ' ^ '  . quotemeta ($_) . "(?= \$ | $stuff_around_mathops ) ",
      " (?<= $stuff_around_mathops)" . quotemeta ($_) . "(?= \$ | $stuff_around_mathops ) ",
    }
    (qw/< > != <> = <= >=/)
  ),
  ( map
    { '\b (?: NOT \s+)?' . $_ . '\b' }
    (qw/IN BETWEEN LIKE/)
  ),
);

my $tokenizer_re_str = join("\n\t|\n",
  ( map { '\b' . $_ . '\b' } @expression_terminator_sql_keywords, 'AND', 'OR', 'NOT'),
  @binary_op_keywords,
);

my $tokenizer_re = qr/ \s* ( $tokenizer_re_str | \( | \) | \? ) \s* /xi;

sub _binary_op_keywords { @binary_op_keywords }

sub parse {
  my $s = shift;

  # tokenize string, and remove all optional whitespace
  my $tokens = [];
  foreach my $token (split $tokenizer_re, $s) {
    push @$tokens, $token if (length $token) && ($token =~ /\S/);
  }

  my $tree = _recurse_parse($tokens, PARSE_TOP_LEVEL);
  return $tree;
}

sub _recurse_parse {
  my ($tokens, $state) = @_;

  my $left;
  while (1) { # left-associative parsing

    my $lookahead = $tokens->[0];
    if ( not defined($lookahead)
          or
        ($state == PARSE_IN_PARENS && $lookahead eq ')')
          or
        ($state == PARSE_IN_EXPR && grep { $lookahead =~ /^ $_ $/xi } ('\)', @expression_terminator_sql_keywords ) )
          or
        ($state == PARSE_RHS && grep { $lookahead =~ /^ $_ $/xi } ('\)', @expression_terminator_sql_keywords, @binary_op_keywords, 'AND', 'OR', 'NOT' ) )
    ) {
      return $left;
    }

    my $token = shift @$tokens;

    # nested expression in ()
    if ($token eq '(' ) {
      my $right = _recurse_parse($tokens, PARSE_IN_PARENS);
      $token = shift @$tokens   or croak "missing closing ')' around block " . unparse ($right);
      $token eq ')'             or croak "unexpected token '$token' terminating block " . unparse ($right);

      $left = $left ? [@$left, [PAREN => [$right] ]]
                    : [PAREN  => [$right] ];
    }
    # AND/OR
    elsif ($token =~ /^ (?: OR | AND ) $/xi )  {
      my $op = uc $token;
      my $right = _recurse_parse($tokens, PARSE_IN_EXPR);

      # Merge chunks if logic matches
      if (ref $right and $op eq $right->[0]) {
        $left = [ (shift @$right ), [$left, map { @$_ } @$right] ];
      }
      else {
       $left = [$op => [$left, $right]];
      }
    }
    # binary operator keywords
    elsif (grep { $token =~ /^ $_ $/xi } @binary_op_keywords ) {
      my $op = uc $token;
      my $right = _recurse_parse($tokens, PARSE_RHS);

      # A between with a simple LITERAL for a 1st RHS argument needs a
      # rerun of the search to (hopefully) find the proper AND construct
      if ($op eq 'BETWEEN' and $right->[0] eq 'LITERAL') {
        unshift @$tokens, $right->[1][0];
        $right = _recurse_parse($tokens, PARSE_IN_EXPR);
      }

      $left = [$op => [$left, $right] ];
    }
    # expression terminator keywords (as they start a new expression)
    elsif (grep { $token =~ /^ $_ $/xi } @expression_terminator_sql_keywords ) {
      my $op = uc $token;
      my $right = _recurse_parse($tokens, PARSE_IN_EXPR);
      $left = $left ? [ $left,  [$op => [$right] ]]
                    : [ $op => [$right] ];
    }
    # NOT (last as to allow all other NOT X pieces first)
    elsif ( $token =~ /^ not $/ix ) {
      my $op = uc $token;
      my $right = _recurse_parse ($tokens, PARSE_RHS);
      $left = $left ? [ @$left, [$op => [$right] ]]
                    : [ $op => [$right] ];

    }
    # literal (eat everything on the right until RHS termination)
    else {
      my $right = _recurse_parse ($tokens, PARSE_RHS);
      $left = $left ? [ $left, [LITERAL => [join ' ', $token, unparse($right)||()] ] ]
                    : [ LITERAL => [join ' ', $token, unparse($right)||()] ];
    }
  }
}

sub unparse {
  my $tree = shift;

  if (not $tree ) {
    return '';
  }
  elsif (ref $tree->[0]) {
    return join (" ", map { unparse ($_) } @$tree);
  }
  elsif ($tree->[0] eq 'LITERAL') {
    return $tree->[1][0];
  }
  elsif ($tree->[0] eq 'PAREN') {
    return sprintf '(%s)', join (" ", map {unparse($_)} @{$tree->[1]});
  }
  elsif ($tree->[0] eq 'OR' or $tree->[0] eq 'AND' or (grep { $tree->[0] =~ /^ $_ $/xi } @binary_op_keywords ) ) {
    return join (" $tree->[0] ", map {unparse($_)} @{$tree->[1]});
  }
  else {
    return sprintf "%s %s\n", $tree->[0], unparse ($tree->[1]);
  }
}


1;

