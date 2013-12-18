use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({
  colormap => {
    select     => ['s(', ')s'],
    where      => ['w(', ')w'],
    from       => ['f(', ')f'],
    join       => ['j(', ')f'],
    on         => ['o(', ')o'],
    'group by' => ['gb(',')gb'],
    'order by' => ['ob(',')ob'],
  },
});

for ( keys %{$sqlat->colormap}) {
  my ($l, $r) = @{$sqlat->colormap->{$_}};
  is($sqlat->format_keyword($_), "$l$_$r", "$_ 'colored' correctly");
}


done_testing;
