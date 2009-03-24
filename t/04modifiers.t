#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use SQL::Abstract::Test import => ['is_same_sql_bind'];

use Data::Dumper;
use SQL::Abstract;

=begin
Test -and -or and -nest modifiers, assuming the following:

  * Modifiers are respected in both hashrefs and arrayrefs (with the obvious limitation of one modifier type per hahsref)
  * Each modifier affects only the immediate element following it
  * In the case of -nestX simply wrap whatever the next element is in a pair of (), regardless of type
  * In the case of -or/-and explicitly setting the logic within a following hashref or arrayref,
    without imposing the logic on any sub-elements of the affected structure
  * Ignore (maybe throw exception?) of the -or/-and modifier if the following element is missing,
    or is of a type other than hash/arrayref

=cut

# no warnings (the -or/-and => { } warning is silly, there is nothing wrong with such usage)
my $and_or_args = {
  and => { stmt => 'WHERE a = ? AND b = ?', bind => [qw/1 2/] },
  or => { stmt => 'WHERE a = ? OR b = ?', bind => [qw/1 2/] },
  or_and => { stmt => 'WHERE ( foo = ? OR bar = ? ) AND baz = ? ', bind => [qw/1 2 3/] },
  or_or => { stmt => 'WHERE foo = ? OR bar = ? OR baz = ?', bind => [qw/1 2 3/] },
  and_or => { stmt => 'WHERE ( foo = ? AND bar = ? ) OR baz = ?', bind => [qw/1 2 3/] },
};

my @and_or_tests = (
  # basic tests
  {
    where => { -and => [a => 1, b => 2] },
    %{$and_or_args->{and}},
  },
  {
    where => [ -and => [a => 1, b => 2] ],
    %{$and_or_args->{and}},
  },
  {
    where => { -or => [a => 1, b => 2] },
    %{$and_or_args->{or}},
  },
  {
    where => [ -or => [a => 1, b => 2] ],
    %{$and_or_args->{or}},
  },

  # test modifiers within hashrefs 
  {
    where => { -or => [
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]},
    %{$and_or_args->{or_or}},
  },
  {
    where => { -and => [
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]},
    %{$and_or_args->{or_and}},
  },

  # test modifiers within arrayrefs 
  {
    where => [ -or => [
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]],
    %{$and_or_args->{or_or}},
  },
  {
    where => [ -and => [
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]],
    %{$and_or_args->{or_and}},
  },

  # test ambiguous modifiers within hashrefs (op extends to to immediate RHS only)
  {
    where => { -and => [ -or =>
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]},
    %{$and_or_args->{or_and}},
  },
  {
    where => { -or => [ -and =>
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]},
    %{$and_or_args->{and_or}},
  },

  # test ambiguous modifiers within arrayrefs (op extends to to immediate RHS only)
  {
    where => [ -and => [ -or =>
      [ foo => 1, bar => 2 ],
      baz => 3,
    ]],
    %{$and_or_args->{or_and}},
  },
  {
    where => [ -or => [ -and =>
      [ foo => 1, bar => 2 ],
      baz => 3
    ]],
    %{$and_or_args->{and_or}},
  },

  # the -or should affect only the next element
  {
    where => { x => {
      -or => { '!=', 1, '>=', 2 }, -like => 'x%'
    }},
    stmt => 'WHERE (x != ? OR x >= ?) AND x LIKE ?',
    bind => [qw/1 2 x%/],
  },
  # the -and should affect only the next element
  {
    where => { x => [ 
      -and => [ 1, 2 ], { -like => 'x%' } 
    ]},
    stmt => 'WHERE (x = ? AND x = ?) OR x LIKE ?',
    bind => [qw/1 2 x%/],
  },
  {
    where => { -and => [a => 1, b => 2], x => 9, -or => { c => 3, d => 4 } },
    stmt => 'WHERE a = ? AND b = ? AND ( c = ? OR d = ? ) AND x = ?',
    bind => [qw/1 2 3 4 9/],
  },
  {
    where => { -and => [a => 1, b => 2, k => [11, 12] ], x => 9, -or => { c => 3, d => 4, l => { '=' => [21, 22] } } },
    stmt => 'WHERE a = ? AND b = ? AND (k = ? OR k = ?) AND ( l = ? OR l = ? OR c = ? OR d = ? ) AND x = ?',
    bind => [qw/1 2 11 12 21 22 3 4 9/],
  },
  {
    where => { -or => [a => 1, b => 2, k => [11, 12] ], x => 9, -and => { c => 3, d => 4, l => { '=' => [21, 22] } } },
    stmt => 'WHERE c = ? AND d = ? AND ( l = ? OR l = ?) AND (a = ? OR b = ? OR k = ? OR k = ?) AND x = ?',
    bind => [qw/3 4 21 22 1 2 11 12 9/],
  },

  {
    # flip logic except where excplicitly requested otherwise
    args => { logic => 'or' },
    where => { -or => [a => 1, b => 2, k => [11, 12] ], x => 9, -and => { c => 3, d => 4, l => { '=' => [21, 22] } } },
    stmt => 'WHERE c = ? AND d = ? AND ( l = ? OR l = ?) AND (a = ? OR b = ? OR k = ? OR k = ?) AND x = ?',
    bind => [qw/3 4 21 22 1 2 11 12 9/],
  },

  {
    where => [ -or => [a => 1, b => 2], -or => { c => 3, d => 4}, e => 5, -and => [ f => 6, g => 7], [ h => 8, i => 9, -and => [ k => 10, l => 11] ], { m => 12, n => 13 }],
    stmt => 'WHERE a = ? OR b = ? OR c = ? OR d = ? OR e = ? OR ( f = ? AND g = ?) OR h = ? OR i = ? OR ( k = ? AND l = ? ) OR (m = ? AND n = ?)',
    bind => [1 .. 13],
  },
  {
    # flip logic except where excplicitly requested otherwise
    args => { logic => 'and' },
    where => [ -or => [a => 1, b => 2], -or => { c => 3, d => 4}, e => 5, -and => [ f => 6, g => 7], [ h => 8, i => 9, -and => [ k => 10, l => 11] ], { m => 12, n => 13 }],
    stmt => 'WHERE (a = ? OR b = ?) AND (c = ? OR d = ?) AND e = ? AND f = ? AND g = ? AND h = ? AND i = ? AND k = ? AND l = ? AND m = ? AND n = ?',
    bind => [1 .. 13],
  },

  ##########
  # some corner cases by ldami (some produce useless SQL, just for clarification on 1.5 direction)
  #

  {
    where => { foo => [
      -and => [ { -like => 'foo%'}, {'>' => 'moo'} ],
      { -like => '%bar', '<' => 'baz'},
      [ {-like => '%alpha'}, {-like => '%beta'} ],
      -or => { '!=' => 'toto', '=' => 'koko' }
    ] },
    stmt => 'WHERE (foo LIKE ? AND foo > ?) OR (foo LIKE ? AND foo < ?) OR (foo LIKE ? OR foo LIKE ?) OR (foo != ? OR foo = ?)',
    bind => [qw/foo% moo %bar baz %alpha %beta toto koko/],
  },
  {
    where => [-and => [{foo => 1}, {bar => 2}, -or => {baz => 3 }] ],
    stmt => 'WHERE foo = ? AND bar = ? AND baz = ?',
    bind => [qw/1 2 3/],
  },
  {
    where => [-and => [{foo => 1}, {bar => 2}, -or => {baz => 3, boz => 4} ] ],
    stmt => 'WHERE foo = ? AND bar = ? AND (baz = ? OR boz = ?)',
    bind => [1 .. 4],
  },

  # -and affects only the first {} thus a noop
  {
    where => { col => [ -and => {'<' => 123}, {'>' => 456 }, {'!=' => 789} ] },
    stmt => 'WHERE col < ? OR col > ? OR col != ?',
    bind => [qw/123 456 789/],
  },

  # -and affects the entire inner [], thus 3 ANDs
  {
    where => { col => [ -and => [{'<' => 123}, {'>' => 456 }, {'!=' => 789}] ] },
    stmt => 'WHERE col < ? AND col > ? AND col != ?',
    bind => [qw/123 456 789/],
  },
);

my @nest_tests = ();      #can not be verified via is_same_sql_bind - need exact matching (parenthesis and all)

my @numbered_tests = ();  #need tests making sure warnings are emitted for modifierN (will go away in SQLA2)

plan tests => @and_or_tests * 3;

for my $case (@and_or_tests) {
    local $Data::Dumper::Terse = 1;

    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    my $sql = SQL::Abstract->new ($case->{args} || {});
    lives_ok (sub { 
      my ($stmt, @bind) = $sql->where($case->{where});
      is_same_sql_bind($stmt, \@bind, $case->{stmt}, $case->{bind})
        || diag "Search term:\n" . Dumper $case->{where};
    });
    is (@w, 0, 'No warnings within and-or tests')
      || diag join "\n", 'Emitted warnings:', @w;
}
