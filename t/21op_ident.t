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

  throws_ok {
    local $sql_maker->{disable_old_special_ops} = 1;
    $sql_maker->where({'-or' => [{'-ident' => 'foo'},'foo']})
  } qr/Illegal.*top-level/;

  throws_ok {
    local $sql_maker->{disable_old_special_ops} = 1;
    $sql_maker->where({'-or' => [{'-ident' => 'foo'},{'=' => \'bozz'}]})
  } qr/Illegal.*top-level/;

  my ($sql, @bind) = $sql_maker->select('artist', '*', { 'artist.name' => { -ident => 'artist.pseudonym' } } );
  is_same_sql_bind (
    $sql,
    \@bind,
    "SELECT *
      FROM ${q}artist${q}
      WHERE ${q}artist${q}.${q}name${q} = ${q}artist${q}.${q}pseudonym${q}
    ",
    [],
  );

  ($sql, @bind) = $sql_maker->update('artist',
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

  ($sql) = $sql_maker->select(
    \(my $from = 'foo JOIN bar ON foo.bar_id = bar.id'),
    [ { -ident => [ 'foo', 'name' ] }, { -ident => [ 'bar', '*' ] } ]
  );

  is_same_sql_bind(
    $sql,
    undef,
    "SELECT ${q}foo${q}.${q}name${q}, ${q}bar${q}.*
     FROM $from"
  );
}

done_testing;
