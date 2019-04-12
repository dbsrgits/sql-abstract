use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [ qw(is_same_sql_bind) ];
use SQL::Abstract::ExtraClauses;

my $sqlac = SQL::Abstract::ExtraClauses->new;

my ($sql, @bind) = $sqlac->select({
  select => [ qw(artist.id artist.name), { -func => [ json_agg => 'cd' ] } ],
  from => [
    artist => -join => [ cd => on => { 'cd.artist_id' => 'artist.id' } ],
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
    FROM artist JOIN cd ON cd.artist_id = artist.id
    WHERE artist.genres @> ?
    ORDER BY artist.name
    GROUP BY artist.id
    HAVING COUNT(cd.id) > ?
  },
  [ [ 'Rock' ], 3 ]
);

done_testing;
