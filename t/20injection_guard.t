use strict;
use warnings;
use Test::More;
use Test::Exception;
use SQL::Abstract::Test import => ['is_same_sql_bind'];
use SQL::Abstract;

my $sqla = SQL::Abstract->new;
my $sqla_q = SQL::Abstract->new(quote_char => '"');

throws_ok( sub {
  $sqla->select(
    'foo',
    [ 'bar' ],
    { 'bobby; tables' => 'bar' },
  );
}, qr/Possible SQL injection attempt/, 'Injection thwarted on unquoted column' );

my ($sql, @bind) = $sqla_q->select(
  'foo',
  [ 'bar' ],
  { 'bobby; tables' => 'bar' },
);

is_same_sql_bind (
  $sql, \@bind,
  'SELECT "bar" FROM "foo" WHERE ( "bobby; tables" = ? )',
  [ 'bar' ],
  'Correct sql with quotes on'
);


for ($sqla, $sqla_q) {

  throws_ok( sub {
    $_->select(
      'foo',
      [ 'bar' ],
      { x => { 'bobby; tables' => 'y' } },
    );
  }, qr/Possible SQL injection attempt/, 'Injection thwarted on top level op');

  throws_ok( sub {
    $_->select(
      'foo',
      [ 'bar' ],
      { x => { '<' => { "-go\ndo some harm" => 'y' } } },
    );
  }, qr/Possible SQL injection attempt/, 'Injection thwarted on chained functions');
}

done_testing;
