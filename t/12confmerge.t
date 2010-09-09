use strict;
use warnings;

use Test::More;

use SQL::Abstract::Tree;

my $tree = SQL::Abstract::Tree->new({
   profile  => 'console',
   colormap => {
      select     => undef,
      'group by' => ['yo', 'seph'] ,
   },
});

is $tree->newline, "\n", 'console profile appears to have been used';
ok !defined $tree->colormap->{select}, 'select correctly got undefined from colormap';

ok eq_array($tree->colormap->{'group by'}, [qw(yo seph)]), 'group by correctly got overridden';
ok ref $tree->colormap->{'order by'}, 'but the rest of the colormap does not get blown away';

done_testing;
