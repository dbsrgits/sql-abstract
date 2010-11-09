use strict;
use warnings;

use Test::More;

BEGIN {
  # ask for a recent DBIC version to skip the 5.6.2 tests as well
  plan skip_all => 'Test temporarily requires DBIx::Class'
    unless eval { require DBIx::Class::Storage::Statistics; DBIx::Class->VERSION('0.08124') };
}

use DBIx::Class::Storage::Debug::PrettyPrint;

my $cap;
open my $fh, '>', \$cap;

my $pp = DBIx::Class::Storage::Debug::PrettyPrint->new({
   show_progress => 1,
   clear_line    => 'CLEAR',
   executing     => 'GOGOGO',
});

$pp->debugfh($fh);

$pp->query_start('SELECT * FROM frew WHERE id = 1');
is(
   $cap,
   qq(SELECT * FROM frew WHERE id = 1 : \nGOGOGO),
   'SQL Logged'
);
$pp->query_end('SELECT * FROM frew WHERE id = 1');
is(
   $cap,
   qq(SELECT * FROM frew WHERE id = 1 : \nGOGOGOCLEAR),
   'SQL Logged'
);

done_testing;
