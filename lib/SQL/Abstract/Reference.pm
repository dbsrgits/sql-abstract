package SQL::Abstract::Reference;

1;

__END__
=head1 NAME

SQL::Abstract::Reference - Reference documentation for L<SQL::Abstract>

=head1 TERMS

=head2 Expression (expr)

The DWIM structure that's passed to most methods by default is referred to
as expression syntax. If you see a variable with C<expr> in the name, or a
comment before a code block saying C<# expr>, this is what's being described.

=head2 Abstract Query Tree (aqt)

The explicit structure that an expression is converted into before it's
rendered into SQL is referred to as an abstract query tree. If you see a
variable with C<aqt> in the name, or a comment before a code block saying
C<# aqt>, this is what's being described.

=head2 SQL and Bind Values (query)

The final result of L<SQL::Abstract> rendering is generally an SQL statement
plus bind values for passing to DBI, ala:

  my ($sql, @bind) = $sqla->some_method(@args);
  my @hashes = @{$dbh->do($sql, { Slice => {} }, @bind)};

If you see a comment before a code block saying C<# query>, the SQL + bind
array is what's being described.

=head2 Expander

An expander subroutine is written as:

  sub {
    my ($sqla, $name, $value, $k) = @_;
    ...
    return $aqt;
  }

$name is the expr node type for node expanders, the op name for op
expanders, and the clause name for clause expanders.

$value is the body of the thing being expanded

If an op expander is being called as the binary operator in a L</hashtriple>
expression, $k will be the hash key to be used as the left hand side
identifier.

This can trivially be converted to an C<ident> type AQT node with:

  my $ident = $sqla->expand_expr({ -ident => $k });

=head2 Renderer

A renderer subroutine looks like:

  sub {
    my ($sqla, $type, $value) = @_;
    ...
    $sqla->join_query_parts($join, @parts);
  }

and can be registered on a per-type, per-op or per-clause basis.

=head1 AQT node types

An AQT node consists of a hashref with a single key, whose name is C<-type>
where 'type' is the node type, and whose value is the data for the node.

The following is an explanation of the built-in AQT type renderers;
additional renderers can be registered as part of the extension system.

=head2 literal

  # expr
  { -literal => [ 'SPANG(?, ?)', 1, 27 ] }

  # query
  SPANG(?, ?)
  [ 1, 27 ]

=head2 ident

  # expr
  { -ident => 'foo' }

  # query
  foo
  []

  # expr
  { -ident => [ 'foo', 'bar' ] }

  # query
  foo.bar
  []

=head2 bind

  # expr
  { -bind => [ 'colname', 'value' ] }

  # query
  ?
  [ 'value' ]

=head2 row

  # expr
  {
    -row => [ { -bind => [ 'r', 1 ] }, { -ident => [ 'clown', 'car' ] } ]
  }

  # query
  (?, clown.car)
  [ 1 ]

=head2 func

  # expr
  {
    -func => [ 'foo', { -ident => [ 'bar' ] }, { -bind => [ undef, 7 ] } ]
  }

  # query
  FOO(bar, ?)
  [ 7 ]

=head2 op

Standard binop:

  # expr
  { -op => [
      '=', { -ident => [ 'bomb', 'status' ] },
      { -value => 'unexploded' },
  ] }

  # query
  bomb.status = ?
  [ 'unexploded' ]

Not:

  # expr
  { -op => [ 'not', { -ident => 'explosive' } ] }

  # query
  (NOT explosive)
  []

Postfix unop: (is_null, is_not_null, asc, desc)

  # expr
  { -op => [ 'is_null', { -ident => [ 'bobby' ] } ] }

  # query
  bobby IS NULL
  []

AND and OR:

  # expr
  { -op =>
      [ 'and', { -ident => 'x' }, { -ident => 'y' }, { -ident => 'z' } ]
  }

  # query
  ( x AND y AND z )
  []

IN (and NOT IN):

  # expr
  { -op => [
      'in', { -ident => 'card' }, { -bind => [ 'card', 3 ] },
      { -bind => [ 'card', 'J' ] },
  ] }

  # query
  card IN ( ?, ? )
  [ 3, 'J' ]

BETWEEN (and NOT BETWEEN):

  # expr
  { -op => [
      'between', { -ident => 'pints' }, { -bind => [ 'pints', 2 ] },
      { -bind => [ 'pints', 4 ] },
  ] }

  # query
  ( pints BETWEEN ? AND ? )
  [ 2, 4 ]

Comma (use -row for parens):

  # expr
  { -op => [ ',', { -literal => [ 1 ] }, { -literal => [ 2 ] } ] }

  # query
  1, 2
  []

=head2 values

  # expr
  { -values =>
      { -row => [ { -bind => [ undef, 1 ] }, { -bind => [ undef, 2 ] } ] }
  }

  # query
  VALUES (?, ?)
  [ 1, 2 ]

  # expr
  { -values => [
      { -row => [ { -literal => [ 1 ] }, { -literal => [ 2 ] } ] },
      { -row => [ { -literal => [ 3 ] }, { -literal => [ 4 ] } ] },
  ] }

  # query
  VALUES (1, 2), (3, 4)
  []

=head2 statement types

AQT node types are also provided for C<select>, C<insert>, C<update> and
C<delete>. These types are handled by the clauses system as discussed later.

=head1 Expressions

=head2 node expr

The simplest expression is just an AQT node:

  # expr
  { -ident => [ 'foo', 'bar' ] }

  # aqt
  { -ident => [ 'foo', 'bar' ] }

  # query
  foo.bar
  []

However, even in the case of an AQT node, the node value will be expanded if
an expander has been registered for that node type:

  # expr
  { -ident => 'foo.bar' }

  # aqt
  { -ident => [ 'foo', 'bar' ] }

  # query
  foo.bar
  []

=head2 identifier hashpair types

=head3 hashtriple

  # expr
  { id => { op => 'value' } }

  # aqt
  { -op =>
      [ 'op', { -ident => [ 'id' ] }, { -bind => [ 'id', 'value' ] } ]
  }

  # query
  id OP ?
  [ 'value' ]

If the value is undef, attempts to convert equality and like ops to IS NULL,
and inequality and not like to IS NOT NULL:

  # expr
  { id => { '!=' => undef } }

  # aqt
  { -op => [ 'is_not_null', { -ident => [ 'id' ] } ] }

  # query
  id IS NOT NULL
  []

=head3 identifier hashpair w/simple value

Equivalent to a hashtriple with an op of '='.

  # expr
  { id => 'value' }

  # aqt
  {
    -op => [ '=', { -ident => [ 'id' ] }, { -bind => [ 'id', 'value' ] } ]
  }

  # query
  id = ?
  [ 'value' ]

(an object value will also follow this code path)

=head3 identifier hashpair w/undef RHS

Converted to IS NULL :

  # expr
  { id => undef }

  # aqt
  { -op => [ 'is_null', { -ident => [ 'id' ] } ] }

  # query
  id IS NULL
  []

(equivalent to the -is operator) :

  # expr
  { id => { -is => undef } }

  # aqt
  { -op => [ 'is_null', { -ident => [ 'id' ] } ] }

  # query
  id IS NULL
  []

=head3 identifier hashpair w/literal RHS

Directly appended to the key, remember you need to provide an operator:

  # expr
  { id => \"= dont_try_this_at_home" }

  # aqt
  { -literal => [ 'id = dont_try_this_at_home' ] }

  # query
  id = dont_try_this_at_home
  []

  # expr
  { id => \[
        "= seriously(?, ?, ?, ?, ?)",
        "use",
        "-ident",
        "and",
        "-func",
      ]
  }

  # aqt
  { -literal =>
      [ 'id = seriously(?, ?, ?, ?, ?)', 'use', -ident => 'and', '-func' ]
  }

  # query
  id = seriously(?, ?, ?, ?, ?)
  [ 'use', -ident => 'and', '-func' ]

(you may absolutely use this when there's no built-in expression type for
what you need and registering a custom one would be more hassle than it's
worth, but, y'know, do try and avoid it)

=head3 identifier hashpair w/arrayref value

Becomes equivalent to a -or over an arrayref of hashrefs with the identifier
as key and the member of the original arrayref as the value:

  # expr
  { id => [ 3, 4, { '>' => 12 } ] }

  # aqt
  { -op => [
      'or',
      { -op => [ '=', { -ident => [ 'id' ] }, { -bind => [ 'id', 3 ] } ] },
      { -op => [ '=', { -ident => [ 'id' ] }, { -bind => [ 'id', 4 ] } ] },
      {
        -op => [ '>', { -ident => [ 'id' ] }, { -bind => [ 'id', 12 ] } ]
      },
  ] }

  # query
  ( id = ? OR id = ? OR id > ? )
  [ 3, 4, 12 ]

  # expr
  { -or => [ { id => 3 }, { id => 4 }, { id => { '>' => 12 } } ] }

  # aqt
  { -op => [
      'or',
      { -op => [ '=', { -ident => [ 'id' ] }, { -bind => [ 'id', 3 ] } ] },
      { -op => [ '=', { -ident => [ 'id' ] }, { -bind => [ 'id', 4 ] } ] },
      {
        -op => [ '>', { -ident => [ 'id' ] }, { -bind => [ 'id', 12 ] } ]
      },
  ] }

  # query
  ( id = ? OR id = ? OR id > ? )
  [ 3, 4, 12 ]

Special Case: If the first element of the arrayref is -or or -and, that's
used as the top level logic op:

  # expr
  { id => [ -and => { '>' => 3 }, { '<' => 6 } ] }

  # aqt
  { -op => [
      'and',
      { -op => [ '>', { -ident => [ 'id' ] }, { -bind => [ 'id', 3 ] } ] },
      { -op => [ '<', { -ident => [ 'id' ] }, { -bind => [ 'id', 6 ] } ] },
  ] }

  # query
  ( id > ? AND id < ? )
  [ 3, 6 ]

=head3 identifier hashpair w/hashref value

Becomes equivalent to a -and over an arrayref of hashtriples constructed
with the identifier as the key and each key/value pair of the original
hashref as the value:

  # expr
  { id => { '<' => 4, '>' => 3 } }

  # aqt
  { -op => [
      'and',
      { -op => [ '<', { -ident => [ 'id' ] }, { -bind => [ 'id', 4 ] } ] },
      { -op => [ '>', { -ident => [ 'id' ] }, { -bind => [ 'id', 3 ] } ] },
  ] }

  # query
  ( id < ? AND id > ? )
  [ 4, 3 ]

is sugar for:

  # expr
  { -and => [ { id => { '<' => 4 } }, { id => { '>' => 3 } } ] }

  # aqt
  { -op => [
      'and',
      { -op => [ '<', { -ident => [ 'id' ] }, { -bind => [ 'id', 4 ] } ] },
      { -op => [ '>', { -ident => [ 'id' ] }, { -bind => [ 'id', 3 ] } ] },
  ] }

  # query
  ( id < ? AND id > ? )
  [ 4, 3 ]

=head2 operator hashpair types

A hashpair whose key begins with a -, or whose key consists entirely of
nonword characters (thereby covering '=', '>', pg json ops, etc.) is
processed as an operator hashpair.

=head3 operator hashpair w/node type

If a node type expander is registered for the key, the hashpair is
treated as a L</node expr>.

=head3 operator hashpair w/registered op

If an expander is registered for the op name, that's run and the
result returned:

  # expr
  { -in => [ 'foo', 1, 2, 3 ] }

  # aqt
  { -op => [
      'in', { -ident => [ 'foo' ] }, { -bind => [ undef, 1 ] },
      { -bind => [ undef, 2 ] }, { -bind => [ undef, 3 ] },
  ] }

  # query
  foo IN ( ?, ?, ? )
  [ 1, 2, 3 ]

=head3 operator hashpair w/not prefix

If the op name starts -not_ this is stripped and turned into a -not
wrapper around the result:

  # expr
  { -not_ident => 'foo' }

  # aqt
  { -op => [ 'not', { -ident => [ 'foo' ] } ] }

  # query
  (NOT foo)
  []

is equivalent to:

  # expr
  { -not => { -ident => 'foo' } }

  # aqt
  { -op => [ 'not', { -ident => [ 'foo' ] } ] }

  # query
  (NOT foo)
  []

=head3 operator hashpair with unknown op

If the C<unknown_unop_always_func> option is set (which is recommended but
defaults to off for backwards compatibility reasons), an unknown op
expands into a C<-func> node:

  # expr
  { -count => { -ident => '*' } }

  # aqt
  { -func => [ 'count', { -ident => [ '*' ] } ] }

  # query
  COUNT(*)
  []

If not, an unknown op will expand into a C<-op> node.

=head2 hashref expr

A hashref with more than one pair becomes a C<-and> over its hashpairs, i.e.

  # expr
  { x => 1, y => 2 }

  # aqt
  { -op => [
      'and',
      { -op => [ '=', { -ident => [ 'x' ] }, { -bind => [ 'x', 1 ] } ] },
      { -op => [ '=', { -ident => [ 'y' ] }, { -bind => [ 'y', 2 ] } ] },
  ] }

  # query
  ( x = ? AND y = ? )
  [ 1, 2 ]

is short hand for:

  # expr
  { -and => [ { x => 1 }, { y => 2 } ] }

  # aqt
  { -op => [
      'and',
      { -op => [ '=', { -ident => [ 'x' ] }, { -bind => [ 'x', 1 ] } ] },
      { -op => [ '=', { -ident => [ 'y' ] }, { -bind => [ 'y', 2 ] } ] },
  ] }

  # query
  ( x = ? AND y = ? )
  [ 1, 2 ]

=head2 arrayref expr

An arrayref becomes a C<-or> over its contents. Arrayrefs, hashrefs and
literals are all expanded and added to the clauses of the C<-or>. If the
arrayref contains a scalar it's treated as the key of a hashpair and the
next element as the value.

  # expr
  [ { x => 1 }, [ { y => 2 }, { z => 3 } ], 'key', 'value', \"lit()" ]

  # aqt
  { -op => [
      'or',
      { -op => [ '=', { -ident => [ 'x' ] }, { -bind => [ 'x', 1 ] } ] },
      { -op => [
          'or', {
            -op => [ '=', { -ident => [ 'y' ] }, { -bind => [ 'y', 2 ] } ]
          }, {
            -op => [ '=', { -ident => [ 'z' ] }, { -bind => [ 'z', 3 ] } ]
          },
      ] }, { -op =>
          [
            '=', { -ident => [ 'key' ] },
            { -bind => [ 'key', 'value' ] },
          ]
      },
      { -literal => [ 'lit()' ] },
  ] }

  # query
  ( x = ? OR ( y = ? OR z = ? ) OR key = ? OR lit() )
  [ 1, 2, 3, 'value' ]

=cut
