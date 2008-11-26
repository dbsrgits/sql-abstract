#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(sum);
use Data::Dumper;

use Test::More;


my @bind_tests = (
  # scalar - equal
  {
    equal => 1,
    bindvals => [
      undef,
      undef,
    ]
  },
  {
    equal => 1,
    bindvals => [
      'foo',
      'foo',
    ]
  },
  {
    equal => 1,
    bindvals => [
      42,
      42,
      '42',
    ]
  },

  # scalarref - equal
  {
    equal => 1,
    bindvals => [
      \'foo',
      \'foo',
    ]
  },
  {
    equal => 1,
    bindvals => [
      \42,
      \42,
      \'42',
    ]
  },

  # arrayref - equal
  {
    equal => 1,
    bindvals => [
      [],
      []
    ]
  },
  {
    equal => 1,
    bindvals => [
      [42],
      [42],
      ['42'],
    ]
  },
  {
    equal => 1,
    bindvals => [
      [1, 42],
      [1, 42],
      ['1', 42],
      [1, '42'],
      ['1', '42'],
    ]
  },

  # hashref - equal
  {
    equal => 1,
    bindvals => [
      { foo => 42 },
      { foo => 42 },
      { foo => '42' },
    ]
  },
  {
    equal => 1,
    bindvals => [
      { foo => 42, bar => 1 },
      { foo => 42, bar => 1 },
      { foo => '42', bar => 1 },
    ]
  },

  # blessed object - equal
  {
    equal => 1,
    bindvals => [
      bless(\(local $_ = 42), 'Life::Universe::Everything'),
      bless(\(local $_ = 42), 'Life::Universe::Everything'),
    ]
  },
  {
    equal => 1,
    bindvals => [
      bless([42], 'Life::Universe::Everything'),
      bless([42], 'Life::Universe::Everything'),
    ]
  },
  {
    equal => 1,
    bindvals => [
      bless({ answer => 42 }, 'Life::Universe::Everything'),
      bless({ answer => 42 }, 'Life::Universe::Everything'),
    ]
  },

  # complex data structure - equal
  {
    equal => 1,
    bindvals => [
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
    ]
  },


  # scalar - different
  {
    equal => 0,
    bindvals => [
      undef,
      'foo',
      42,
    ]
  },

  # scalarref - different
  {
    equal => 0,
    bindvals => [
      \undef,
      \'foo',
      \42,
    ]
  },

  # arrayref - different
  {
    equal => 0,
    bindvals => [
      [undef],
      ['foo'],
      [42],
    ]
  },

  # hashref - different
  {
    equal => 0,
    bindvals => [
      { foo => undef },
      { foo => 'bar' },
      { foo => 42 },
    ]
  },

  # different types
  {
    equal => 0,
    bindvals => [
      'foo',
      \'foo',
      ['foo'],
      { foo => 'bar' },
    ]
  },

  # complex data structure - different
  {
    equal => 0,
    bindvals => [
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [43, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'baz', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { bar => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quuux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [0, 1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, 3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \4, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quuux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5, 6] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => 4 } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5], quuux => 1 } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8, 9 ],
    ]
  },
);


plan tests => 1 + sum
  map { $_ * ($_ - 1) / 2 }
    map { scalar @{$_->{bindvals}} }
      @bind_tests;

use_ok('SQL::Abstract::Test', import => [qw(eq_sql eq_bind is_same_sql_bind)]);

for my $test (@bind_tests) {
  my $bindvals = $test->{bindvals};
  while (@$bindvals) {
    my $bind1 = shift @$bindvals;
    foreach my $bind2 (@$bindvals) {
      my $equal = eq_bind($bind1, $bind2);
      if ($test->{equal}) {
        ok($equal, "equal bind values considered equal");
      } else {
        ok(!$equal, "different bind values considered not equal");
      }

      if ($equal ^ $test->{equal}) {
        diag("bind1: " . Dumper($bind1));
        diag("bind2: " . Dumper($bind2));
      }
    }
  }
}
