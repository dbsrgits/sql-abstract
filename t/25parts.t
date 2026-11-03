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

# format() folds a statement across lines and changes only whitespace:
# with whitespace taken out, the folded text reads like the stringified SQL
{
  require SQL::Abstract;
  my $sqla = SQL::Abstract->new(lazy_join_sql_parts => 1);
  my @statements = (
    [ select => 'people', '*',
      { -or => [ a => 1, b => 2 ], age => { '>' => 18 }, status => 'x' } ],
    [ select => 'people', [qw(alpha beta gamma delta epsilon)],
      { -or => [ { a => 1, b => 2 }, { c => 3, d => [ 4, 5 ] } ] },
      [qw(alpha beta)] ],
    [ update => 'people', { name => 'x', age => 3 },
      { -or => [ id => 1, id => { '>' => 100 } ], status => 'x' } ],
    [ delete => 'people',
      { -or => [ id => 1, name => { -like => 'x%' } ],
        status => { -in => [ 1, 2, 3 ] } } ],
    [ insert => 'people', { name => 'x', age => 3, status => 'y' } ],
    [ select => 'people',
      [ \'coalesce(some_rather_long_column_name, another_rather_long_column_name, 0) AS x' ],
      { id => 1 } ],
    [ select => 'a_table_with_an_exceptionally_long_name_that_runs_past_the_width', '*' ],
    [ select => [ 'people', 'pets' ],
      [ 'people.name', \'count(pets.id) AS pet_count', 'people.city' ],
      { 'people.id' => \'= pets.owner_id',
        -or => [ 'pets.kind' => [qw(cat dog bird)],
                 'people.age' => { -between => [ 18, 65 ] } ],
        'people.status' => { '!=' => 'gone' } },
      [ 'people.name', { -desc => 'people.city' } ] ],
    [ select => 'people', '*',
      { -not => \'a_really_quite_long_literal_condition_that_does_not_fit_in_narrow_widths' } ],
    [ select => 'people', '*',
      { -and => [ { -or => [ a => 1, b => 2 ] }, { -or => [ c => 3, d => 4 ] },
                  { -or => [ e => 5, f => 6 ] } ] } ],
  );
  my $squash = sub { (my $t = shift) =~ s/\s+//g; $t };
  for my $st (@statements) {
    my ($method, @args) = @$st;
    my ($sql) = $sqla->$method(@args);
    my %folded = map +($_ => eval { $sql->format(max_width => $_) }), 5 .. 100;
    my @bad = grep {
      !defined($folded{$_}) or $squash->($folded{$_}) ne $squash->("$sql")
    } sort { $a <=> $b } keys %folded;
    ok(!@bad, "format keeps every token of: $sql")
      or diag "differs at max_width @bad";
    my @nl = grep { defined($folded{$_}) and $folded{$_} =~ /\n\z/ }
      sort { $a <=> $b } keys %folded;
    ok(!@nl, "format ends without a newline: $sql")
      or diag "ends with a newline at max_width @nl";
  }

  my ($sql) = $sqla->select('people', '*',
    { -or => [ a => 1, b => 2 ], age => { '>' => 18 }, status => 'x' });
  my $folded = $sql->format(max_width => 20);
  is($folded, join("\n",
    'SELECT * FROM people',
    'WHERE (',
    '  ( a = ? OR b = ? )',
    '  AND age > ?',
    '  AND status = ?',
    ')',
  ), 'a folded AND list starts each continuation line with AND');

  my ($list) = $sqla->select('people', [qw(alpha beta gamma delta)], { name => 1 });
  my $cols = $list->format(max_width => 21);
  is($cols, join("\n",
    'SELECT',
    '  alpha, beta, gamma,',
    '  delta',
    'FROM people',
    'WHERE name = ?',
  ), 'a folded comma list keeps the comma before its last item');
}

done_testing;
