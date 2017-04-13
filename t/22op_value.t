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

  my ($sql, @bind) = $sql_maker->select('artist', '*', { arr1 => { -value => [1,2] }, arr2 => { '>', { -value => [3,4] } }, field => [5,6] } );

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

  {
    local $SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /Supplying an undefined argument to '(?:NOT )?LIKE'/ };

    ($sql, @bind) = $sql_maker->where({
      c1 => undef,
      c2 => { -value => undef },
      c3 => { '=' => { -value => undef } },
      c4 => { '!=' => { -value => undef } },
      c5 => { '<>' => { -value => undef } },
      c6 => { '-like' => { -value => undef } },
      c7 => { '-not_like' => { -value => undef } },
      c8 => { 'is' => { -value => undef } },
      c9 => { 'is not' => { -value => undef } },
    });

    is_same_sql_bind (
      $sql,
      \@bind,
      "WHERE  ${q}c1${q} IS NULL
          AND ${q}c2${q} IS NULL
          AND ${q}c3${q} IS NULL
          AND ${q}c4${q} IS NOT NULL
          AND ${q}c5${q} IS NOT NULL
          AND ${q}c6${q} IS NULL
          AND ${q}c7${q} IS NOT NULL
          AND ${q}c8${q} IS NULL
          AND ${q}c9${q} IS NOT NULL
      ",
      [],
    );
  }
}}

done_testing;
