#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use SQL::Abstract::Test import => ['is_same_sql_bind'];

use Data::Dumper;
use SQL::Abstract;

=begin
Test -between and -in 
  * between
    * [scalar, scalar]
    * [scalarref, scalar]
    * [scalar, scalarref]
    * [scalarref, scalarref]
    * \[]
      * \["? AND ?", scalar, scalar]
      * \["1 AND ?", scalar]
      * \["? AND 2", scalar]
      * \["1 AND 2"]
=cut

my @in_between_tests = (
  {
    where => { x => { -between => [1, 2] } },
    stmt => 'WHERE (x BETWEEN ? AND ?)',
    bind => [qw/1 2/],
    test => '-between with two placeholders',
  },
  {
    where => { x => { -between => [\"1", 2] } },
    stmt => 'WHERE (x BETWEEN 1 AND ?)',
    bind => [qw/2/],
    test => '-between with one literal sql arg and one placeholder',
  },
  {
    where => { x => { -between => [1, \"2"] } },
    stmt => 'WHERE (x BETWEEN ? AND 2)',
    bind => [qw/1/],
    test => '-between with one placeholder and one literal sql arg',
  },
  {
    where => { x => { -between => [\'current_date - 1', \'current_date - 0'] } },
    stmt => 'WHERE (x BETWEEN current_date - 1 AND current_date - 0)',
    bind => [],
    test => '-between with two literal sql arguments',
  },
  {
    where => { x => { -between => \['? AND ?', 1, 2] } },
    stmt => 'WHERE (x BETWEEN ? AND ?)',
    bind => [1,2],
    test => '-between with literal sql with placeholders (\["? AND ?", scalar, scalar])',
  },
  {
    where => { x => { -between => \["'something' AND ?", 2] } },
    stmt => "WHERE (x BETWEEN 'something' AND ?)",
    bind => [2],
    test => '-between with literal sql with one literal arg and one placeholder (\["\'something\' AND ?", scalar])',
  },
  {
    where => { x => { -between => \["? AND 'something'", 1] } },
    stmt => "WHERE (x BETWEEN ? AND 'something')",
    bind => [1],
    test => '-between with literal sql with one placeholder and one literal arg (\["? AND \'something\'", scalar])',
  },
  {
    where => { x => { -between => \["'this' AND 'that'"] } },
    stmt => "WHERE (x BETWEEN 'this' AND 'that')",
    bind => [],
    test => '-between with literal sql with two literal args (\["\'this\' AND \'that\'"])',
  },
);

plan tests => @in_between_tests*3;

for my $case (@in_between_tests) {
  TODO: {
    local $TODO = $case->{todo} if $case->{todo};

    local $Data::Dumper::Terse = 1;

    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    my $sql = SQL::Abstract->new ($case->{args} || {});
    lives_ok (sub { 
      my ($stmt, @bind) = $sql->where($case->{where});
      is_same_sql_bind(
        $stmt,
        \@bind,
        $case->{stmt},
        $case->{bind},
      )
        || diag "Search term:\n" . Dumper $case->{where};
    });
    is (@w, 0, $case->{test} || 'No warnings within in-between tests')
      || diag join "\n", 'Emitted warnings:', @w;
  }
}
