#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use SQL::Abstract::Test import => ['is_same_sql_bind'];

use Data::Dumper;
use SQL::Abstract;

=begin
Test -and -or and -nest/-nestX modifiers, assuming the following:

  * Modifiers are respected in both hashrefs and arrayrefs (with the obvious limitation of one modifier type per hahsref)
  * Each modifier affects only the immediate element following it
  * In the case of -nestX simply wrap whatever the next element is in a pair of (), regardless of type
  * In the case of -or/-and explicitly setting the logic within a following hashref or arrayref,
    without imposing the logic on any sub-elements of the affected structure
  * Ignore (maybe throw exception?) of the -or/-and modifier if the following element is missing,
    or is of a type other than hash/arrayref

=cut


my @handle_tests = ();

plan tests => @handle_tests * 2 + 1;
ok (1);

for my $case (@handle_tests) {
    local $Data::Dumper::Terse = 1;
    my $sql = SQL::Abstract->new;
    my($stmt, @bind);
    lives_ok (sub { 
      ($stmt, @bind) = $sql->where($case->{where}, $case->{order});
      is_same_sql_bind($stmt, \@bind, $case->{stmt}, $case->{bind})
        || diag "Search term:\n" . Dumper $case->{where};
    });
}
