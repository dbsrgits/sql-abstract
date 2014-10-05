use strict;
use warnings;

use Test::More;

BEGIN {
  # ask for a recent DBIC version to skip the 5.6 tests as well
  plan skip_all => 'Test temporarily requires DBIx::Class'
    unless eval { require DBIx::Class::Storage::Statistics; DBIx::Class->VERSION('0.08124') };

  plan skip_all => 'Test does not properly work with the pre-0.082800 DBIC trials'
    if DBIx::Class->VERSION =~ /^0.082700\d\d/;
}

use DBIx::Class::Storage::Debug::PrettyPrint;

my $cap;
open my $fh, '>', \$cap;

my $pp = DBIx::Class::Storage::Debug::PrettyPrint->new({
   profile => 'none',
   squash_repeats => 1,
   fill_in_placeholders => 1,
   placeholder_surround => ['', ''],
   show_progress => 0,
});

$pp->debugfh($fh);

$pp->query_start('SELECT * FROM frew WHERE id = ?', q('1'));
is(
   $cap,
   qq(SELECT * FROM frew WHERE id = '1'\n),
   'SQL Logged'
);

open $fh, '>', \$cap;
$pp->query_start('SELECT * FROM frew WHERE id = ?', q('2'));
is(
   $cap,
   qq(... : '2'\n),
   'Repeated SQL ellided'
);

open $fh, '>', \$cap;
$pp->query_start('SELECT * FROM frew WHERE id = ?', q('3'));
is(
   $cap,
   qq(... : '3'\n),
   'Repeated SQL ellided'
);

open $fh, '>', \$cap;
$pp->query_start('SELECT * FROM frew WHERE id = ?', q('4'));
is(
   $cap,
   qq(... : '4'\n),
   'Repeated SQL ellided'
);

open $fh, '>', \$cap;
$pp->query_start('SELECT * FROM bar WHERE id = ?', q('4'));
is(
   $cap,
   qq(SELECT * FROM bar WHERE id = '4'\n),
   'New SQL Logged'
);

open $fh, '>', \$cap;
$pp->query_start('SELECT * FROM frew WHERE id = ?', q('1'));
is(
   $cap,
   qq(SELECT * FROM frew WHERE id = '1'\n),
   'New SQL Logged'
);

done_testing;
