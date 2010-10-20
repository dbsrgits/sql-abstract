use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

ok my $placeholders = [100,'xxx'];
ok my $sqlat = SQL::Abstract::Tree->new({profile=>'html'});
ok my $out = $sqlat->format('SELECT * FROM bar WHERE x = ?', $placeholders);

is $placeholders->[0], 100,
  'did not mess up a placeholder';

done_testing;
