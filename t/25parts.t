use strict;
use warnings;

use Test::More;

# SQL::Abstract::Parts used to `use Module::Runtime ()` without ever
# calling it. Module::Runtime was dropped as a prerequisite in 2.000001,
# so on a system without it installed the dead `use` made Parts.pm - and
# thus the whole render path that builds Parts objects - fail to compile.
# Block Module::Runtime and confirm Parts.pm still loads.
{
  local @INC = (
    sub { die "Module::Runtime is blocked for this test\n"
            if $_[1] eq 'Module/Runtime.pm'; return },
    @INC,
  );
  delete $INC{'Module/Runtime.pm'};
  my $ok = eval { require SQL::Abstract::Parts; 1 };
  ok($ok, 'SQL::Abstract::Parts loads without Module::Runtime')
    or diag $@;
}

# basic behaviour (previously entirely untested)
my $p = SQL::Abstract::Parts->new(' AND ', 'a = 1', 'b = 2');
isa_ok($p, 'SQL::Abstract::Parts');
is("$p", 'a = 1 AND b = 2', 'stringify joins the parts with the join string');

my $nested = SQL::Abstract::Parts->new(
  ' OR ', $p, SQL::Abstract::Parts->new(' AND ', 'c = 3', 'd = 4'),
);
is(
  "$nested",
  'a = 1 AND b = 2 OR c = 3 AND d = 4',
  'stringify recurses into nested Parts',
);

is_deeply(
  [ SQL::Abstract::Parts->new(', ', 'x', 'y')->to_array ],
  [ ', ', 'x', 'y' ],
  'to_array returns the join string followed by the parts',
);

done_testing;
