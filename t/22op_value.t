use strict;
use warnings;

use Test::More;
use SQL::Abstract;
use SQL::Abstract::Test import => [qw/is_same_sql_bind/];

for my $q ('', '"') {
for my $col_btype (0,1) {

  my $sql_maker = SQL::Abstract->new(
    quote_char => $q,
    name_sep => $q ? '.' : '',
    $col_btype ? (bindtype => 'columns') : (),
  );

  my ($sql, @bind) = $sql_maker->select ('artist', '*', { arr1 => { -value => [1,2] }, arr2 => { '>', { -value => [3,4] } }, field => [5,6] } );

  is_same_sql_bind (
    $sql,
    \@bind,
    "SELECT *
      FROM ${q}artist${q}
      WHERE ${q}arr1${q} = ? AND
            ${q}arr2${q} > ? AND
            ( ${q}field${q} = ? OR ${q}field${q} = ? )
    ",
    [
      $col_btype
        ? (
          [ arr1 => [ 1, 2 ] ],
          [ arr2 => [ 3, 4 ] ],
          [ field => 5 ],
          [ field => 6 ],
        ) : (
          [ 1, 2 ],
          [ 3, 4 ],
          5,
          6,
        )
    ],
  );
}}

done_testing;
