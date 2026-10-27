use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [ qw(is_same_sql_bind) ];
use SQL::Abstract;

# Plain scalars inside a nested statement (where, having, set, values) are
# values and must become bind values - also when the statement sits in a
# place where plain scalars are identifiers (select list, order by, group
# by, returning, from, join). Otherwise the value lands in the SQL text,
# unescaped when quote_char is not set.

my $sqla  = SQL::Abstract->new;
my $sqlac = SQL::Abstract->new->plugin('+ExtraClauses');

my $sub = sub {
  +{ -select => { select => 'x', from => 'bar', where => { id => $_[0] } } }
};

my @tests = (
  [ 'select list',
    [ $sqla->select('foo', [ $sub->(1) ]) ],
    'SELECT (SELECT x FROM bar WHERE id = ?) FROM foo', [ 1 ] ],
  [ 'order by',
    [ $sqla->select('foo', '*', {}, [ $sub->('1 OR 1=1') ]) ],
    'SELECT * FROM foo ORDER BY (SELECT x FROM bar WHERE id = ?)',
    [ '1 OR 1=1' ] ],
  [ 'nested twice in select list',
    [ $sqla->select('foo', [ { -select => {
        select => [ $sub->(2) ], from => 'baz', where => { k => 3 },
      } } ]) ],
    'SELECT (SELECT (SELECT x FROM bar WHERE id = ?) FROM baz WHERE k = ?)
     FROM foo',
    [ 2, 3 ] ],
  [ 'insert returning',
    [ $sqla->insert('foo', { a => 1 }, { returning => [ $sub->(4) ] }) ],
    'INSERT INTO foo (a) VALUES (?) RETURNING (SELECT x FROM bar WHERE id = ?)',
    [ 1, 4 ] ],
  [ 'from -as',
    [ $sqlac->select({ select => '*', from => [ $sub->(5), -as => 't' ] }) ],
    'SELECT * FROM (SELECT x FROM bar WHERE id = ?) AS t', [ 5 ] ],
  [ 'join to',
    [ $sqlac->select({
        select => '*',
        from => [ 'foo',
          -join => { to => $sub->(6), as => 'j', on => { 'j.x' => 'foo.x' } } ],
      }) ],
    'SELECT * FROM foo JOIN (SELECT x FROM bar WHERE id = ?) AS j
     ON j.x = foo.x',
    [ 6 ] ],
  [ 'group by',
    [ $sqlac->select({ select => '*', from => 'foo', group_by => [ $sub->(7) ] }) ],
    'SELECT * FROM foo GROUP BY (SELECT x FROM bar WHERE id = ?)', [ 7 ] ],
  [ 'having inside a nested select',
    [ $sqlac->select({ select => '*', from => 'foo', order_by => [
        { -select => {
            select => 'x', from => 'bar', group_by => 'x',
            having => { x => 8 },
        } },
      ] }) ],
    'SELECT * FROM foo ORDER BY (SELECT x FROM bar GROUP BY x HAVING x = ?)',
    [ 8 ] ],
  [ 'update set inside a nested statement',
    [ $sqlac->select({ select => '*', from => 'foo', order_by => [
        { -update => { target => 'bar', set => { a => 9 }, returning => 'a' } },
      ] }) ],
    'SELECT * FROM foo ORDER BY (UPDATE bar SET a = ? RETURNING a)', [ 9 ] ],
  [ '-values in from',
    [ $sqlac->select({
        select => '*', from => [ { -values => [ [ 10, 11 ] ] }, -as => 'v' ],
      }) ],
    'SELECT * FROM (VALUES (?, ?)) AS v', [ 10, 11 ] ],
);

for my $t (@tests) {
  my ($name, $got, $sql, $bind) = @$t;
  my ($got_sql, @got_bind) = @$got;
  is_same_sql_bind($got_sql, \@got_bind, $sql, $bind, $name);
}

{
  my $sqla_q = SQL::Abstract->new(quote_char => '"', name_sep => '.');
  my ($sql, @bind) = $sqla_q->select('foo', [ $sub->('a" OR 1=1 --') ]);
  is_same_sql_bind(
    $sql, \@bind,
    'SELECT (SELECT "x" FROM "bar" WHERE "id" = ?) FROM "foo"',
    [ 'a" OR 1=1 --' ],
    'quoted: nested where value is a bind value, not a quoted identifier',
  );
}

{
  # plain scalars in the select list itself are still identifiers
  my ($sql, @bind) = $sqlac->select({
    select => [ 'a', { -select => { select => 'b', from => 'bar' } } ],
    from => 'foo',
  });
  is_same_sql_bind(
    $sql, \@bind,
    'SELECT a, (SELECT b FROM bar) FROM foo', [],
    'select list scalars stay identifiers',
  );
}

done_testing;
