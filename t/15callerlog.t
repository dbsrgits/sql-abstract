use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $tree = SQL::Abstract::Tree->new({
   include_caller => 1,
   caller_depth   => 0,
});

my $tree2 = SQL::Abstract::Tree->new({
   include_caller => 1,
   caller_depth   => 1,
});
my $out = $tree->_caller_info(1);
ok $out =~ /callerlog/ && $out =~ /line 16/, 'caller info is right for basic test';

my $o2;
sub lolz { $o2 = $tree2->_caller_info(1) }

lolz;
ok $o2 =~ /callerlog/ && $o2 =~ /line 22/, 'caller info is right for more nested test';

ok !$tree2->_caller_info(2), 'caller info is blank unless arg == 1';
done_testing;
