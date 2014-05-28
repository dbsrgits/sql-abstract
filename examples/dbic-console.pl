#!/sur/bin/env perl

use warnings;
use strict;

use DBIx::Class::Storage::Debug::PrettyPrint;

my $pp = DBIx::Class::Storage::Debug::PrettyPrint->new({
   profile => 'console',
   show_progress => 1,
});

$pp->txn_begin;
$pp->query_start("SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE ?", q('station'));
sleep 1;
$pp->query_end("SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE ?", q('station'));
$pp->txn_commit;

