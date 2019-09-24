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
C<# aqt>#, this is what's being described.

=head2 SQL and Bind Values (query)

The final result of L<SQL::Abstract> rendering is generally an SQL statement
plus bind values for passing to DBI, ala:

  my ($sql, @bind) = $sqla->some_method(@args);
  my @hashes = @{$dbh->do($sql, { Slice => {} }, @bind)};

If you see a comment before a code block saying C<# query>, the SQL + bind
array is what's being described.

=head1 AQT node types

An AQT node consists of a hashref with a single key, whose name is C<-type>
where 'type' is the node type, and whose value is the data for the node.

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

=head2
