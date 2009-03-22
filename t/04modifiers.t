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

# no warnings
my @and_or_tests = (
  {
    where => { -and => [a => 1, b => 2] },
    stmt => 'WHERE a = ? AND b = ?',
    bind => [qw/1 2/],
  },
  {
    where => [ -and => [a => 1, b => 2] ],
    stmt => 'WHERE a = ? AND b = ?',
    bind => [qw/1 2/],
  },
  {
    where => { -or => [a => 1, b => 2] },
    stmt => 'WHERE a = ? OR b = ?',
    bind => [qw/1 2/],
  },
  {
    where => [ -or => [a => 1, b => 2] ],
    stmt => 'WHERE a = ? OR b = ?',
    bind => [qw/1 2/],
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
    # things should remain the same as above, hashrefs not affected
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
    # while the arrayref logic should flip, except when requested otherwise
    args => { logic => 'and' },
    where => [ -or => [a => 1, b => 2], -or => { c => 3, d => 4}, e => 5, -and => [ f => 6, g => 7], [ h => 8, i => 9, -and => [ k => 10, l => 11] ], { m => 12, n => 13 }],
    stmt => 'WHERE (a = ? OR b = ?) AND (c = ? OR d = ?) AND e = ? AND f = ? AND g = ? AND h = ? AND i = ? AND k = ? AND l = ? AND m = ? AND n = ?',
    bind => [1 .. 13],
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
