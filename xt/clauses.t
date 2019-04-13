use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [ qw(is_same_sql_bind is_same_sql) ];
use SQL::Abstract::ExtraClauses;

my $sqlac = SQL::Abstract::ExtraClauses->new;

my ($sql, @bind) = $sqlac->select({
  select => [ qw(artist.id artist.name), { -func => [ json_agg => 'cd' ] } ],
  from => [
    { artists => { -as => 'artist' } },
    -join => [ cds => as => 'cd' => on => { 'cd.artist_id' => 'artist.id' } ],
  ],
  where => { 'artist.genres', => { '@>', { -value => [ 'Rock' ] } } },
  order_by => 'artist.name',
  group_by => 'artist.id',
  having => { '>' => [ { -func => [ count => 'cd.id' ] }, 3 ] }
});

is_same_sql_bind(
  $sql, \@bind,
  q{
    SELECT artist.id, artist.name, JSON_AGG(cd)
    FROM artists AS artist JOIN cds AS cd ON cd.artist_id = artist.id
    WHERE artist.genres @> ?
    ORDER BY artist.name
    GROUP BY artist.id
    HAVING COUNT(cd.id) > ?
  },
  [ [ 'Rock' ], 3 ]
);

($sql) = $sqlac->select({
  select => [ 'a' ],
  from => [ { -values => [ [ 1, 2 ], [ 3, 4 ] ] }, -as => [ qw(t a b) ] ],
});

is_same_sql($sql, q{SELECT a FROM (VALUES (1, 2), (3, 4)) AS t(a,b)});

($sql) = $sqlac->update({
  update => 'employees',
  set => { sales_count => { sales_count => { '+', \1 } } },
  from => 'accounts',
  where => {
    'accounts.name' => { '=' => \"'Acme Corporation'" },
    'employees.id' => { -ident => 'accounts.sales_person' },
  }
});

is_same_sql(
  $sql,
  q{UPDATE employees SET sales_count = sales_count + 1 FROM accounts
    WHERE accounts.name = 'Acme Corporation'
    AND employees.id = accounts.sales_person
  }
);

($sql) = $sqlac->update({
  update => [ qw(tab1 tab2) ],
  set => {
    'tab1.column1' => { -ident => 'value1' },
    'tab1.column2' => { -ident => 'value2' },
  },
  where => { 'tab1.id' => { -ident => 'tab2.id' } },
});

is_same_sql(
  $sql,
  q{UPDATE tab1, tab2 SET tab1.column1 = value1, tab1.column2 = value2
     WHERE tab1.id = tab2.id}
);

is_same_sql(
  $sqlac->delete({
    from => 'x',
    using => 'y',
    where => { 'x.id' => { -ident => 'y.x_id' } }
  }),
  q{DELETE FROM x USING y WHERE x.id = y.x_id}
);

is_same_sql(
  $sqlac->select({
    select => [ 'x.*', 'y.*' ],
    from => [ 'x', -join => [ 'y', using => 'y_id' ] ],
  }),
  q{SELECT x.*, y.* FROM x JOIN y USING (y_id)},
);

done_testing;
