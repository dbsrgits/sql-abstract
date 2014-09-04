use strict;
use warnings;

use Test::More;
use Test::Exception;
use SQL::Abstract;
use SQL::Abstract::Test import => [qw/is_same_sql_bind/];


for my $q ('', '"') {
  my $sql_maker = SQL::Abstract->new(
    quote_char => $q,
    name_sep => $q ? '.' : '',
  );

  throws_ok {
    $sql_maker->where({ foo => { -ident => undef } })
  } qr/-ident requires a single plain scalar argument/;

  my ($sql, @bind) = $sql_maker->select ('artist', '*', { 'artist.name' => { -ident => 'artist.pseudonym' } } );
  is_same_sql_bind (
    $sql,
    \@bind,
    "SELECT *
      FROM ${q}artist${q}
      WHERE ${q}artist${q}.${q}name${q} = ${q}artist${q}.${q}pseudonym${q}
    ",
    [],
  );

  ($sql, @bind) = $sql_maker->update ('artist',
    { 'artist.name' => { -ident => 'artist.pseudonym' } },
    { 'artist.name' => { '!=' => { -ident => 'artist.pseudonym' } } },
  );
  is_same_sql_bind (
    $sql,
    \@bind,
    "UPDATE ${q}artist${q}
      SET ${q}artist${q}.${q}name${q} = ${q}artist${q}.${q}pseudonym${q}
      WHERE ${q}artist${q}.${q}name${q} != ${q}artist${q}.${q}pseudonym${q}
    ",
    [],
  );
}

done_testing;
