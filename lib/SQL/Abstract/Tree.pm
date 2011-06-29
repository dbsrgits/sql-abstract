package SQL::Abstract::Tree;

use strict;
use warnings;
no warnings 'qw';
use Carp;

use Hash::Merge qw//;

use base 'Class::Accessor::Grouped';

__PACKAGE__->mk_group_accessors( simple => $_ ) for qw(
   newline indent_string indent_amount colormap indentmap fill_in_placeholders
   placeholder_surround
);

my $merger = Hash::Merge->new;

$merger->specify_behavior({
   SCALAR => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { [ $_[0], @{$_[1]} ] },
      HASH   => sub { $_[1] },
   },
   ARRAY => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { $_[1] },
      HASH   => sub { $_[1] },
   },
   HASH => {
      SCALAR => sub { $_[1] },
      ARRAY  => sub { [ values %{$_[0]}, @{$_[1]} ] },
      HASH   => sub { Hash::Merge::_merge_hashes( $_[0], $_[1] ) },
   },
}, 'SQLA::Tree Behavior' );

my $op_look_ahead = '(?: (?= [\s\)\(\;] ) | \z)';
my $op_look_behind = '(?: (?<= [\,\s\)\(] ) | \A )';

my $quote_left = qr/[\`\'\"\[]/;
my $quote_right = qr/[\`\'\"\]]/;

my $placeholder_re = qr/(?: \? | \$\d+ )/x;

# These SQL keywords always signal end of the current expression (except inside
# of a parenthesized subexpression).
# Format: A list of strings that will be compiled to extended syntax ie.
# /.../x) regexes, without capturing parentheses. They will be automatically
# anchored to op boundaries (excluding quotes) to match the whole token.
my @expression_start_keywords = (
  'SELECT',
  'UPDATE',
  'INSERT \s+ INTO',
  'DELETE \s+ FROM',
  'FROM',
  'SET',
  '(?:
    (?:
        (?: (?: LEFT | RIGHT | FULL ) \s+ )?
        (?: (?: CROSS | INNER | OUTER ) \s+ )?
    )?
    JOIN
  )',
  'ON',
  'WHERE',
  '(?: DEFAULT \s+ )? VALUES',
  '(?:NOT \s+)? EXISTS',
  'GROUP \s+ BY',
  'HAVING',
  'ORDER \s+ BY',
  'SKIP',
  'FIRST',
  'LIMIT',
  'OFFSET',
  'FOR',
  'UNION',
  'INTERSECT',
  'EXCEPT',
  'BEGIN \s+ WORK',
  'COMMIT',
  'ROLLBACK \s+ TO \s+ SAVEPOINT',
  'ROLLBACK',
  'SAVEPOINT',
  'RELEASE \s+ SAVEPOINT',
  'RETURNING',
  'ROW_NUMBER \s* \( \s* \) \s+ OVER',
);

my $expr_start_re = join ("\n\t|\n", @expression_start_keywords );
$expr_start_re = qr/ $op_look_behind (?i: $expr_start_re ) $op_look_ahead /x;

# These are binary operator keywords always a single LHS and RHS
# * AND/OR are handled separately as they are N-ary
# * so is NOT as being unary
# * BETWEEN without paranthesis around the ANDed arguments (which
#   makes it a non-binary op) is detected and accomodated in
#   _recurse_parse()

# this will be included in the $binary_op_re, the distinction is interesting during
# testing as one is tighter than the other, plus mathops have different look
# ahead/behind (e.g. "x"="y" )
my @math_op_keywords = (qw/ < > != <> = <= >= /);
my $math_re = join ("\n\t|\n", map
  { "(?: (?<= [\\w\\s] | $quote_right ) | \\A )"  . quotemeta ($_) . "(?: (?= [\\w\\s] | $quote_left ) | \\z )" }
  @math_op_keywords
);
$math_re = qr/$math_re/x;

sub _math_op_re { $math_re }


my $binary_op_re = '(?: NOT \s+)? (?:' . join ('|', qw/IN BETWEEN R?LIKE/) . ')';
$binary_op_re = join "\n\t|\n",
  "$op_look_behind (?i: $binary_op_re ) $op_look_ahead",
  $math_re,
  $op_look_behind . 'IS (?:\s+ NOT)?' . "(?= \\s+ NULL \\b | $op_look_ahead )",
;
$binary_op_re = qr/$binary_op_re/x;

sub _binary_op_re { $binary_op_re }

my $all_known_re = join("\n\t|\n",
  $expr_start_re,
  $binary_op_re,
  "$op_look_behind (?i: AND|OR|NOT|\\* ) $op_look_ahead",
  (map { quotemeta $_ } qw/, ( )/),
  $placeholder_re,
);

$all_known_re = qr/$all_known_re/x;

#this one *is* capturing for the split below
# splits on whitespace if all else fails
my $tokenizer_re = qr/ \s* ( $all_known_re ) \s* | \s+ /x;

# Parser states for _recurse_parse()
use constant PARSE_TOP_LEVEL => 0;
use constant PARSE_IN_EXPR => 1;
use constant PARSE_IN_PARENS => 2;
use constant PARSE_IN_FUNC => 3;
use constant PARSE_RHS => 4;

my $expr_term_re = qr/ ^ (?: $expr_start_re | \) ) $/x;
my $rhs_term_re = qr/ ^ (?: $expr_term_re | $binary_op_re | (?i: AND | OR | NOT | \, ) ) $/x;
my $func_start_re = qr/^ (?: \* | $placeholder_re | \( ) $/x;

my %indents = (
   select        => 0,
   update        => 0,
   'insert into' => 0,
   'delete from' => 0,
   from          => 0,
   where         => 0,
   join          => 1,
   'left join'   => 1,
   on            => 2,
   having        => 0,
   'group by'    => 0,
   'order by'    => 0,
   set           => 1,
   into          => 1,
   values        => 1,
   limit         => 1,
   offset        => 1,
   skip          => 1,
   first         => 1,
);

my %profiles = (
   console => {
      fill_in_placeholders => 1,
      placeholder_surround => ['?/', ''],
      indent_string => ' ',
      indent_amount => 2,
      newline       => "\n",
      colormap      => {},
      indentmap     => \%indents,

      eval { require Term::ANSIColor }
        ? do {
          my $c = \&Term::ANSIColor::color;

          my $red     = [$c->('red')    , $c->('reset')];
          my $cyan    = [$c->('cyan')   , $c->('reset')];
          my $green   = [$c->('green')  , $c->('reset')];
          my $yellow  = [$c->('yellow') , $c->('reset')];
          my $blue    = [$c->('blue')   , $c->('reset')];
          my $magenta = [$c->('magenta'), $c->('reset')];
          my $b_o_w   = [$c->('black on_white'), $c->('reset')];
          (
            placeholder_surround => [$c->('black on_magenta'), $c->('reset')],
            colormap => {
              'begin work'            => $b_o_w,
              commit                  => $b_o_w,
              rollback                => $b_o_w,
              savepoint               => $b_o_w,
              'rollback to savepoint' => $b_o_w,
              'release savepoint'     => $b_o_w,

              select                  => $red,
              'insert into'           => $red,
              update                  => $red,
              'delete from'           => $red,

              set                     => $cyan,
              from                    => $cyan,

              where                   => $green,
              values                  => $yellow,

              join                    => $magenta,
              'left join'             => $magenta,
              on                      => $blue,

              'group by'              => $yellow,
              having                  => $yellow,
              'order by'              => $yellow,

              skip                    => $green,
              first                   => $green,
              limit                   => $green,
              offset                  => $green,
            }
          );
        } : (),
   },
   console_monochrome => {
      fill_in_placeholders => 1,
      placeholder_surround => ['?/', ''],
      indent_string => ' ',
      indent_amount => 2,
      newline       => "\n",
      colormap      => {},
      indentmap     => \%indents,
   },
   html => {
      fill_in_placeholders => 1,
      placeholder_surround => ['<span class="placeholder">', '</span>'],
      indent_string => '&nbsp;',
      indent_amount => 2,
      newline       => "<br />\n",
      colormap      => {
         select        => ['<span class="select">'  , '</span>'],
         'insert into' => ['<span class="insert-into">'  , '</span>'],
         update        => ['<span class="select">'  , '</span>'],
         'delete from' => ['<span class="delete-from">'  , '</span>'],

         set           => ['<span class="set">', '</span>'],
         from          => ['<span class="from">'    , '</span>'],

         where         => ['<span class="where">'   , '</span>'],
         values        => ['<span class="values">', '</span>'],

         join          => ['<span class="join">'    , '</span>'],
         'left join'   => ['<span class="left-join">','</span>'],
         on            => ['<span class="on">'      , '</span>'],

         'group by'    => ['<span class="group-by">', '</span>'],
         having        => ['<span class="having">',   '</span>'],
         'order by'    => ['<span class="order-by">', '</span>'],

         skip          => ['<span class="skip">',   '</span>'],
         first         => ['<span class="first">',  '</span>'],
         limit         => ['<span class="limit">',  '</span>'],
         offset        => ['<span class="offset">', '</span>'],

         'begin work'  => ['<span class="begin-work">', '</span>'],
         commit        => ['<span class="commit">', '</span>'],
         rollback      => ['<span class="rollback">', '</span>'],
         savepoint     => ['<span class="savepoint">', '</span>'],
         'rollback to savepoint' => ['<span class="rollback-to-savepoint">', '</span>'],
         'release savepoint'     => ['<span class="release-savepoint">', '</span>'],
      },
      indentmap     => \%indents,
   },
   none => {
      colormap      => {},
      indentmap     => {},
   },
);

sub new {
   my $class = shift;
   my $args  = shift || {};

   my $profile = delete $args->{profile} || 'none';

   die "No such profile '$profile'!" unless exists $profiles{$profile};

   my $data = $merger->merge( $profiles{$profile}, $args );

   bless $data, $class
}

sub parse {
  my ($self, $s) = @_;

  # tokenize string, and remove all optional whitespace
  my $tokens = [];
  foreach my $token (split $tokenizer_re, $s) {
    push @$tokens, $token if (
      defined $token
        and
      length $token
        and
      $token =~ /\S/
    );
  }
  $self->_recurse_parse($tokens, PARSE_TOP_LEVEL);
}

{
# this is temporary, lists can be parsed *without* recursing, but
# it requires a massive rewrite of the AST generator
no warnings qw/recursion/;
sub _recurse_parse {
  my ($self, $tokens, $state) = @_;

  my $left;
  while (1) { # left-associative parsing

    my $lookahead = $tokens->[0];
    if ( not defined($lookahead)
          or
        ($state == PARSE_IN_PARENS && $lookahead eq ')')
          or
        ($state == PARSE_IN_EXPR && $lookahead =~ $expr_term_re )
          or
        ($state == PARSE_RHS && $lookahead =~ $rhs_term_re )
          or
        ($state == PARSE_IN_FUNC && $lookahead !~ $func_start_re) # if there are multiple values - the parenthesis will switch the $state
    ) {
      return $left||();
    }

    my $token = shift @$tokens;

    # nested expression in ()
    if ($token eq '(' ) {
      my $right = $self->_recurse_parse($tokens, PARSE_IN_PARENS);
      $token = shift @$tokens   or croak "missing closing ')' around block " . $self->unparse($right);
      $token eq ')'             or croak "unexpected token '$token' terminating block " . $self->unparse($right);

      $left = $left ? [$left, [PAREN => [$right||()] ]]
                    : [PAREN  => [$right||()] ];
    }
    # AND/OR and LIST (,)
    elsif ($token =~ /^ (?: OR | AND | \, ) $/xi )  {
      my $op = ($token eq ',') ? 'LIST' : uc $token;

      my $right = $self->_recurse_parse($tokens, PARSE_IN_EXPR) || [];

      # Merge chunks if logic matches
      if (ref $right and @$right and $op eq $right->[0]) {
        $left = [ (shift @$right ), [$left||[], map { @$_ } @$right] ];
      }
      else {
        $left = [$op => [ $left||[], $right ]];
      }
    }
    # binary operator keywords
    elsif ( $token =~ /^ $binary_op_re $ /x ) {
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
    elsif ( $token =~ / ^ $expr_start_re $ /x ) {
      my $op = uc $token;
      my $right = $self->_recurse_parse($tokens, PARSE_IN_EXPR);
      $left = $left ? [ $left,  [$op => [$right||()] ]]
                   : [ $op => [$right||()] ];
    }
    # NOT
    elsif ( $token =~ /^ NOT $/ix ) {
      my $op = uc $token;
      my $right = $self->_recurse_parse ($tokens, PARSE_RHS);
      $left = $left ? [ @$left, [$op => [$right||()] ]]
                    : [ $op => [$right||()] ];

    }
    elsif ( $token =~ $placeholder_re) {
      $left = $left ? [ $left, [ PLACEHOLDER => [ $token ] ] ]
                    : [ PLACEHOLDER => [ $token ] ];
    }
    # we're now in "unknown token" land - start eating tokens until
    # we see something familiar
    else {
      my $right;

      # check if the current token is an unknown op-start
      if (@$tokens and $tokens->[0] =~ $func_start_re) {
        $right = [ $token => [ $self->_recurse_parse($tokens, PARSE_IN_FUNC) || () ] ];
      }
      else {
        $right = [ LITERAL => [ $token ] ];
      }

      $left = $left ? [ $left, $right ]
                    : $right;
    }
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

my %starters = (
   select        => 1,
   update        => 1,
   'insert into' => 1,
   'delete from' => 1,
);

sub pad_keyword {
   my ($self, $keyword, $depth) = @_;

   my $before = '';
   if (defined $self->indentmap->{lc $keyword}) {
      $before = $self->newline . $self->indent($depth + $self->indentmap->{lc $keyword});
   }
   $before = '' if $depth == 0 and defined $starters{lc $keyword};
   return [$before, ''];
}

sub indent { ($_[0]->indent_string||'') x ( ( $_[0]->indent_amount || 0 ) * $_[1] ) }

sub _is_key {
   my ($self, $tree) = @_;
   $tree = $tree->[0] while ref $tree;

   defined $tree && defined $self->indentmap->{lc $tree};
}

sub fill_in_placeholder {
   my ($self, $bindargs) = @_;

   if ($self->fill_in_placeholders) {
      my $val = shift @{$bindargs} || '';
      my $quoted = $val =~ s/^(['"])(.*)\1$/$2/;
      my ($left, $right) = @{$self->placeholder_surround};
      $val =~ s/\\/\\\\/g;
      $val =~ s/'/\\'/g;
      $val = qq('$val') if $quoted;
      return qq($left$val$right)
   }
   return '?'
}

# FIXME - terrible name for a user facing API
sub unparse {
  my ($self, $tree, $bindargs) = @_;
  $self->_unparse($tree, [@{$bindargs||[]}], 0);
}

sub _unparse {
  my ($self, $tree, $bindargs, $depth) = @_;

  if (not $tree or not @$tree) {
    return '';
  }

  $self->_parenthesis_unroll($tree);
  my ($car, $cdr) = @{$tree}[0,1];

  if (! defined $car or (! ref $car and ! defined $cdr) ) {
    require Data::Dumper;
    Carp::confess( sprintf ( "Internal error - malformed branch at depth $depth:\n%s",
      Data::Dumper::Dumper($tree)
    ) );
  }

  if (ref $car) {
    return join (' ', map $self->_unparse($_, $bindargs, $depth), @$tree);
  }
  elsif ($car eq 'LITERAL') {
    return $cdr->[0];
  }
  elsif ($car eq 'PLACEHOLDER') {
    return $self->fill_in_placeholder($bindargs);
  }
  elsif ($car eq 'PAREN') {
    return sprintf ('( %s )',
      join (' ', map { $self->_unparse($_, $bindargs, $depth + 2) } @{$cdr} )
        .
      ($self->_is_key($cdr)
        ? ( $self->newline||'' ) . $self->indent($depth + 1)
        : ''
      )
    );
  }
  elsif ($car eq 'AND' or $car eq 'OR') {
    return ($self->newline||'') . join (" $car ". ($self->newline||''),
        map  $self->indent($depth + 1) . $self->_unparse($_, $bindargs, $depth), @{$cdr});
  }
  elsif ($car =~ / ^ $binary_op_re $ /x ) {
    return join (" $car ", map $self->_unparse($_, $bindargs, $depth), @{$cdr});
  }
  elsif ($car eq 'LIST' ) {
      return ($self->newline||'') . join (', ' . ($self->newline||''),
          map $self->indent($depth + 1) . $self->_unparse($_, $bindargs, $depth), @{$cdr});
  }
  else {
    my ($l, $r) = @{$self->pad_keyword($car, $depth)};

    return sprintf "$l%s%s%s$r",
      $self->format_keyword($car),
      ( ref $cdr eq 'ARRAY' and ref $cdr->[0] eq 'ARRAY' and $cdr->[0][0] and $cdr->[0][0] eq 'PAREN' )
        ? ''    # mysql--
        : ' '
      ,
      $self->_unparse($cdr, $bindargs, $depth),
    ;
  }
}

# All of these keywords allow their parameters to be specified with or without parenthesis without changing the semantics
my @unrollable_ops = (
  'ON',
  'WHERE',
  'GROUP \s+ BY',
  'HAVING',
  'ORDER \s+ BY',
  'I?LIKE',
);
my $unrollable_ops_re = join ' | ', @unrollable_ops;
$unrollable_ops_re = qr/$unrollable_ops_re/xi;

sub _parenthesis_unroll {
  my $self = shift;
  my $ast = shift;

  #return if $self->parenthesis_significant;
  return unless (ref $ast and ref $ast->[1]);

  my $changes;
  do {
    my @children;
    $changes = 0;

    for my $child (@{$ast->[1]}) {
      # the current node in this loop is *always* a PAREN
      if (! ref $child or ! @$child or $child->[0] ne 'PAREN') {
        push @children, $child;
        next;
      }

      # unroll nested parenthesis
      while ( @{$child->[1]} && $child->[1][0][0] eq 'PAREN') {
        $child = $child->[1][0];
        $changes++;
      }

      # if the parenthesis are wrapped around an AND/OR matching the parent AND/OR - open the parenthesis up and merge the list
      if (
        ( $ast->[0] eq 'AND' or $ast->[0] eq 'OR')
            and
          $child->[1][0][0] eq $ast->[0]
      ) {
        push @children, @{$child->[1][0][1]};
        $changes++;
      }

      # if the parent operator explcitly allows it nuke the parenthesis
      elsif ( $ast->[0] =~ $unrollable_ops_re ) {
        push @children, $child->[1][0];
        $changes++;
      }

      # only *ONE* LITERAL or placeholder element
      # as an AND/OR/NOT argument
      elsif (
        @{$child->[1]} == 1 && (
          $child->[1][0][0] eq 'LITERAL'
            or
          $child->[1][0][0] eq 'PLACEHOLDER'
        ) && (
          $ast->[0] eq 'AND' or $ast->[0] eq 'OR' or $ast->[0] eq 'NOT'
        )
      ) {
        push @children, $child->[1][0];
        $changes++;
      }

      # only one element in the parenthesis which is a binary op
      # and has exactly two grandchildren
      # the only time when we can *not* unroll this is when both
      # the parent and the child are mathops (in which case we'll
      # break precedence) or when the child is BETWEEN (special
      # case)
      elsif (
        @{$child->[1]} == 1
          and
        $child->[1][0][0] =~ SQL::Abstract::Tree::_binary_op_re()
          and
        $child->[1][0][0] ne 'BETWEEN'
          and
        @{$child->[1][0][1]} == 2
          and
        ! (
          $child->[1][0][0] =~ SQL::Abstract::Tree::_math_op_re()
            and
          $ast->[0] =~ SQL::Abstract::Tree::_math_op_re()
        )
      ) {
        push @children, $child->[1][0];
        $changes++;
      }

      # a function binds tighter than a mathop - see if our ancestor is a
      # mathop, and our content is:
      # a single non-mathop child with a single PAREN grandchild which
      # would indicate mathop ( nonmathop ( ... ) )
      # or a single non-mathop with a single LITERAL ( nonmathop foo )
      # or a single non-mathop with a single PLACEHOLDER ( nonmathop ? )
      elsif (
        @{$child->[1]} == 1
          and
        @{$child->[1][0][1]} == 1
          and
        $ast->[0] =~ SQL::Abstract::Tree::_math_op_re()
          and
        $child->[1][0][0] !~ SQL::Abstract::Tree::_math_op_re
          and
        (
          $child->[1][0][1][0][0] eq 'PAREN'
            or
          $child->[1][0][1][0][0] eq 'LITERAL'
            or
          $child->[1][0][1][0][0] eq 'PLACEHOLDER'
        )
      ) {
        push @children, $child->[1][0];
        $changes++;
      }


      # otherwise no more mucking for this pass
      else {
        push @children, $child;
      }
    }

    $ast->[1] = \@children;

  } while ($changes);

}

sub format { my $self = shift; $self->unparse($self->parse($_[0]), $_[1]) }

1;

=pod

=head1 NAME

SQL::Abstract::Tree - Represent SQL as an AST

=head1 SYNOPSIS

 my $sqla_tree = SQL::Abstract::Tree->new({ profile => 'console' });

 print $sqla_tree->format('SELECT * FROM foo WHERE foo.a > 2');

 # SELECT *
 #   FROM foo
 #   WHERE foo.a > 2

=head1 METHODS

=head2 new

 my $sqla_tree = SQL::Abstract::Tree->new({ profile => 'console' });

 $args = {
   profile => 'console',      # predefined profile to use (default: 'none')
   fill_in_placeholders => 1, # true for placeholder population
   placeholder_surround =>    # The strings that will be wrapped around
              [GREEN, RESET], # populated placeholders if the above is set
   indent_string => ' ',      # the string used when indenting
   indent_amount => 2,        # how many of above string to use for a single
                              # indent level
   newline       => "\n",     # string for newline
   colormap      => {
     select => [RED, RESET], # a pair of strings defining what to surround
                             # the keyword with for colorization
     # ...
   },
   indentmap     => {
     select        => 0,     # A zero means that the keyword will start on
                             # a new line
     from          => 1,     # Any other positive integer means that after
     on            => 2,     # said newline it will get that many indents
     # ...
   },
 }

Returns a new SQL::Abstract::Tree object.  All arguments are optional.

=head3 profiles

There are four predefined profiles, C<none>, C<console>, C<console_monochrome>,
and C<html>.  Typically a user will probably just use C<console> or
C<console_monochrome>, but if something about a profile bothers you, merely
use the profile and override the parts that you don't like.

=head2 format

 $sqlat->format('SELECT * FROM bar WHERE x = ?', [1])

Takes C<$sql> and C<\@bindargs>.

Returns a formatting string based on the string passed in

=head2 parse

 $sqlat->parse('SELECT * FROM bar WHERE x = ?')

Returns a "tree" representing passed in SQL.  Please do not depend on the
structure of the returned tree.  It may be stable at some point, but not yet.

=head2 unparse

 $sqlat->unparse($tree_structure, \@bindargs)

Transform "tree" into SQL, applying various transforms on the way.

=head2 format_keyword

 $sqlat->format_keyword('SELECT')

Currently this just takes a keyword and puts the C<colormap> stuff around it.
Later on it may do more and allow for coderef based transforms.

=head2 pad_keyword

 my ($before, $after) = @{$sqlat->pad_keyword('SELECT')};

Returns whitespace to be inserted around a keyword.

=head2 fill_in_placeholder

 my $value = $sqlat->fill_in_placeholder(\@bindargs)

Removes last arg from passed arrayref and returns it, surrounded with
the values in placeholder_surround, and then surrounded with single quotes.

=head2 indent

Returns as many indent strings as indent amounts times the first argument.

=head1 ACCESSORS

=head2 colormap

See L</new>

=head2 fill_in_placeholders

See L</new>

=head2 indent_amount

See L</new>

=head2 indent_string

See L</new>

=head2 indentmap

See L</new>

=head2 newline

See L</new>

=head2 placeholder_surround

See L</new>

