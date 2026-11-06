use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [ qw(is_same_sql_bind) ];
use SQL::Abstract;

# An arrayref as a column value in insert() / update() is a value: one bind
# value (an array datatype), never SQL text. Data decoded from JSON or a
# repeated form field turns into arrayrefs, and before this the first
# element went into the SQL as-is. Literal SQL is \[ $sql, @bind ];
# array_datatypes => 0 restores the old literal meaning.

my $sqla = SQL::Abstract->new;

sub same_sql_bind {
  my ($got, $sql, $bind, $name) = @_;
  my ($got_sql, @got_bind) = @$got;
  is_same_sql_bind($got_sql, \@got_bind, $sql, $bind, $name);
}

my $evil = '(SELECT password FROM users LIMIT 1)';

same_sql_bind(
  [ $sqla->insert('t', { name => [ $evil ] }) ],
  'INSERT INTO t (name) VALUES (?)', [ [ $evil ] ],
  'insert: arrayref column value is one bind value by default',
);

same_sql_bind(
  [ $sqla->insert('t', [ 1, [ $evil ] ]) ],
  'INSERT INTO t VALUES (?, ?)', [ 1, [ $evil ] ],
  'insert with a list of values: arrayref is one bind value',
);

same_sql_bind(
  [ $sqla->update('t', { name => [ 'x, is_admin = 1' ] }, { id => 1 }) ],
  'UPDATE t SET name = ? WHERE id = ?', [ [ 'x, is_admin = 1' ], 1 ],
  'update: arrayref column value is one bind value by default',
);

is_deeply(
  [ $sqla->values({ name => [ 'x', 'y' ], id => 1 }) ],
  [ 1, [ 'x', 'y' ] ],
  'values() matches insert(): the arrayref is one bind value',
);

same_sql_bind(
  [ $sqla->insert('t', { a => \[ 'lower(?)', 'X' ] }) ],
  'INSERT INTO t (a) VALUES (lower(?))', [ 'X' ],
  'insert: \[ $sql, @bind ] is still literal SQL',
);

same_sql_bind(
  [ $sqla->update('t', { a => \[ 'a + ?', 1 ] }) ],
  'UPDATE t SET a = a + ?', [ 1 ],
  'update: \[ $sql, @bind ] is still literal SQL',
);

my $legacy = SQL::Abstract->new(array_datatypes => 0);

same_sql_bind(
  [ $legacy->insert('t', { a => [ 'lower(?)', 'X' ] }) ],
  'INSERT INTO t (a) VALUES (lower(?))', [ 'X' ],
  'array_datatypes => 0: insert keeps the arrayref as literal SQL',
);

same_sql_bind(
  [ $legacy->update('t', { a => [ 'a + ?', 1 ] }) ],
  'UPDATE t SET a = a + ?', [ 1 ],
  'array_datatypes => 0: update keeps the arrayref as literal SQL',
);

is_deeply(
  [ $legacy->values({ a => [ 'lower(?)', 'X' ] }) ],
  [ 'X' ],
  'array_datatypes => 0: values() returns the binds of the literal',
);

# generate() and AUTOLOAD (allow_autoload) follow the same rule

is_deeply(
  [ $sqla->generate('update t', { name => [ $evil ] }) ],
  [ 'UPDATE T SET name = ?', [ $evil ] ],
  'generate: arrayref in a hash is one bind value by default',
);

is_deeply(
  [ $sqla->generate('insert into t', [ 1, [ $evil ] ]) ],
  [ 'INSERT INTO T (?, ?)', 1, [ $evil ] ],
  'generate: arrayref in a list of values is one bind value by default',
);

is_deeply(
  [ SQL::Abstract->new(bindtype => 'columns')
      ->generate('update t', { name => [ $evil ] }) ],
  [ 'UPDATE T SET name = ?', [ name => [ $evil ] ] ],
  'generate: arrayref bind value follows bindtype columns',
);

is_deeply(
  [ SQL::Abstract->new(allow_autoload => 1)->update_t({ name => [ $evil ] }) ],
  [ 'UPDATE_T SET name = ?', [ $evil ] ],
  'AUTOLOAD: arrayref column value is one bind value by default',
);

is_deeply(
  [ $sqla->generate('update t', { a => \[ 'a + ?', 1 ] }) ],
  [ 'UPDATE T SET a = a + ?', 1 ],
  'generate: \[ $sql, @bind ] in a hash is literal SQL',
);

is_deeply(
  [ $sqla->generate('insert into t', [ \[ 'lower(?)', 'X' ] ]) ],
  [ 'INSERT INTO T (lower(?))', 'X' ],
  'generate: \[ $sql, @bind ] in a list of values is literal SQL',
);

is_deeply(
  [ $legacy->generate('update t', { a => [ 'a + ?', 1 ] }) ],
  [ 'UPDATE T SET a = a + ?', 1 ],
  'array_datatypes => 0: generate keeps the arrayref in a hash as literal SQL',
);

is_deeply(
  [ $legacy->generate('insert into t', [ [ 'lower(?)', 'X' ] ]) ],
  [ 'INSERT INTO T (lower(?))', 'X' ],
  'array_datatypes => 0: generate keeps the arrayref in a list as literal SQL',
);

done_testing;
