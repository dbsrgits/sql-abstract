package SQL::Abstract::Tree;

use strict;
use warnings;
use Carp;


use base 'Class::Accessor::Grouped';

__PACKAGE__->mk_group_accessors( simple => $_ ) for qw(
   newline indent_string indent_amount colormap indentmap
);

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
  'UPDATE',
  'INSERT \s+ INTO',
  'DELETE \s+ FROM',
  'FROM',
  'SET',
  '(?:
    (?:
        (?: \b (?: LEFT | RIGHT | FULL ) \s+ )?
        (?: \b (?: CROSS | INNER | OUTER ) \s+ )?
    )?
    JOIN
  )',
  'ON',
  'WHERE',
  'VALUES',
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
  'ROW_NUMBER \s* \( \s* \) \s+ OVER',
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

my %indents = (
   select        => 0,
   update        => 0,
   'insert into' => 0,
   'delete from' => 0,
   from          => 1,
   where         => 1,
   join          => 1,
   'left join'   => 1,
   on            => 2,
   'group by'    => 1,
   'order by'    => 1,
   set           => 1,
   into          => 1,
   values        => 2,
);

my %profiles = (
   console => {
      indent_string => ' ',
      indent_amount => 2,
      newline       => "\n",
      colormap      => {},
      indentmap     => { %indents },
   },
   console_monochrome => {
      indent_string => ' ',
      indent_amount => 2,
      newline       => "\n",
      colormap      => {},
      indentmap     => { %indents },
   },
   html => {
      indent_string => '&nbsp;',
      indent_amount => 2,
      newline       => "<br />\n",
      colormap      => {
         select        => ['<span class="select">'  , '</span>'],
         'insert into' => ['<span class="insert-into">'  , '</span>'],
         update        => ['<span class="select">'  , '</span>'],
         'delete from' => ['<span class="delete-from">'  , '</span>'],
         where         => ['<span class="where">'   , '</span>'],
         from          => ['<span class="from">'    , '</span>'],
         join          => ['<span class="join">'    , '</span>'],
         on            => ['<span class="on">'      , '</span>'],
         'group by'    => ['<span class="group-by">', '</span>'],
         'order by'    => ['<span class="order-by">', '</span>'],
         set           => ['<span class="set">', '</span>'],
         into          => ['<span class="into">', '</span>'],
         values        => ['<span class="values">', '</span>'],
      },
      indentmap     => { %indents },
   },
   none => {
      colormap      => {},
      indentmap     => {},
   },
);

eval {
   require Term::ANSIColor;
   $profiles{console}->{colormap} = {
      select        => [Term::ANSIColor::color('red'), Term::ANSIColor::color('reset')],
      'insert into' => [Term::ANSIColor::color('red'), Term::ANSIColor::color('reset')],
      update        => [Term::ANSIColor::color('red'), Term::ANSIColor::color('reset')],
      'delete from' => [Term::ANSIColor::color('red'), Term::ANSIColor::color('reset')],

      set           => [Term::ANSIColor::color('cyan'), Term::ANSIColor::color('reset')],
      from          => [Term::ANSIColor::color('cyan'), Term::ANSIColor::color('reset')],

      where         => [Term::ANSIColor::color('green'), Term::ANSIColor::color('reset')],
      values        => [Term::ANSIColor::color('yellow'), Term::ANSIColor::color('reset')],

      join          => [Term::ANSIColor::color('magenta'), Term::ANSIColor::color('reset')],
      'left join'   => [Term::ANSIColor::color('magenta'), Term::ANSIColor::color('reset')],
      on            => [Term::ANSIColor::color('blue'), Term::ANSIColor::color('reset')],

      'group by'    => [Term::ANSIColor::color('yellow'), Term::ANSIColor::color('reset')],
      'order by'    => [Term::ANSIColor::color('yellow'), Term::ANSIColor::color('reset')],
   };
};

sub new {
   my ($class, $args) = @_;

   my $profile = delete $args->{profile} || 'none';
   my $data = {%{$profiles{$profile}}, %{$args||{}}};

   bless $data, $class
}

sub parse {
  my ($self, $s) = @_;

  # tokenize string, and remove all optional whitespace
  my $tokens = [];
  foreach my $token (split $tokenizer_re, $s) {
    push @$tokens, $token if (length $token) && ($token =~ /\S/);
  }

  my $tree = $self->_recurse_parse($tokens, PARSE_TOP_LEVEL);
  return $tree;
}

sub _recurse_parse {
  my ($self, $tokens, $state) = @_;

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
      my $right = $self->_recurse_parse($tokens, PARSE_IN_PARENS);
      $token = shift @$tokens   or croak "missing closing ')' around block " . $self->unparse($right);
      $token eq ')'             or croak "unexpected token '$token' terminating block " . $self->unparse($right);

      $left = $left ? [@$left, [PAREN => [$right] ]]
                    : [PAREN  => [$right] ];
    }
    # AND/OR
    elsif ($token =~ /^ (?: OR | AND ) $/xi )  {
      my $op = uc $token;
      my $right = $self->_recurse_parse($tokens, PARSE_IN_EXPR);

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
      my $right = $self->_recurse_parse($tokens, PARSE_RHS);

      # A between with a simple LITERAL for a 1st RHS argument needs a
      # rerun of the search to (hopefully) find the proper AND construct
      if ($op eq 'BETWEEN' and $right->[0] eq 'LITERAL') {
        unshift @$tokens, $right->[1][0];
        $right = $self->_recurse_parse($tokens, PARSE_IN_EXPR);
      }

      $left = [$op => [$left, $right] ];
    }
    # expression terminator keywords (as they start a new expression)
    elsif (grep { $token =~ /^ $_ $/xi } @expression_terminator_sql_keywords ) {
      my $op = uc $token;
      my $right = $self->_recurse_parse($tokens, PARSE_IN_EXPR);
      $left = $left ? [ $left,  [$op => [$right] ]]
                    : [ $op => [$right] ];
    }
    # NOT (last as to allow all other NOT X pieces first)
    elsif ( $token =~ /^ not $/ix ) {
      my $op = uc $token;
      my $right = $self->_recurse_parse ($tokens, PARSE_RHS);
      $left = $left ? [ @$left, [$op => [$right] ]]
                    : [ $op => [$right] ];

    }
    # literal (eat everything on the right until RHS termination)
    else {
      my $right = $self->_recurse_parse ($tokens, PARSE_RHS);
      $left = $left ? [ $left, [LITERAL => [join ' ', $token, $self->unparse($right)||()] ] ]
                    : [ LITERAL => [join ' ', $token, $self->unparse($right)||()] ];
    }
  }
}

sub format_keyword {
  my ($self, $keyword) = @_;

  if (my $around = $self->colormap->{lc $keyword}) {
     $keyword = "$around->[0]$keyword$around->[1]";
  }

  return $keyword
}

sub whitespace {
   my ($self, $keyword, $depth) = @_;

   my $before = '';
   if (defined $self->indentmap->{lc $keyword}) {
      $before = $self->newline . $self->indent($depth + $self->indentmap->{lc $keyword});
   }
   $before = '' if $depth == 0 and lc $keyword eq 'select';
   return [$before, ' '];
}

sub indent { ($_[0]->indent_string||'') x ( ( $_[0]->indent_amount || 0 ) * $_[1] ) }

sub _is_select {
   my $tree = shift;
   $tree = $tree->[0] while ref $tree;

   defined $tree && lc $tree eq 'select';
}

sub unparse {
  my ($self, $tree, $depth) = @_;

  $depth ||= 0;

  if (not $tree ) {
    return '';
  }

  my $car = $tree->[0];
  my $cdr = $tree->[1];

  if (ref $car) {
    return join ('', map $self->unparse($_, $depth), @$tree);
  }
  elsif ($car eq 'LITERAL') {
    return $cdr->[0];
  }
  elsif ($car eq 'PAREN') {
    return '(' .
      join(' ',
        map $self->unparse($_, $depth + 2), @{$cdr}) .
    (_is_select($cdr)?( $self->newline||'' ).$self->indent($depth + 1):'') . ') ';
  }
  elsif ($car eq 'OR' or $car eq 'AND' or (grep { $car =~ /^ $_ $/xi } @binary_op_keywords ) ) {
    return join (" $car ", map $self->unparse($_, $depth), @{$cdr});
  }
  else {
    my ($l, $r) = @{$self->whitespace($car, $depth)};
    return sprintf "$l%s %s$r", $self->format_keyword($car), $self->unparse($cdr, $depth);
  }
}

sub format { my $self = shift; $self->unparse($self->parse(@_)) }

1;

=pod

=head1 SYNOPSIS

 my $sqla_tree = SQL::Abstract::Tree->new({ profile => 'console' });

 print $sqla_tree->format('SELECT * FROM foo WHERE foo.a > 2');

 # SELECT *
 #   FROM foo
 #   WHERE foo.a > 2

=head1 METHODS

=head2 new

 my $sqla_tree = SQL::Abstract::Tree->new({ profile => 'console' });

=head2 format

 $sqlat->format('SELECT * FROM bar')

Returns a formatting string based on wthe string passed in
