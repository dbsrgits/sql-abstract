use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({});

is(
   $sqlat->format('SELECT foo AS bar FROM baz ORDER BY x + ? DESC, baz.g'),
   'SELECT foo AS bar FROM baz ORDER BY x + ? DESC, baz.g',
   'complex order by correctly reassembled'
);

done_testing;
