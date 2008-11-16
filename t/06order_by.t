#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use SQL::Abstract;

use SQL::Abstract::Test import => ['is_same_sql_bind'];
my @cases = 
  (
   {
    given => \'colA DESC',
    expects => ' ORDER BY colA DESC',
    expects_quoted => ' ORDER BY colA DESC',
   },
   {
    given => 'colA',
    expects => ' ORDER BY colA',
    expects_quoted => ' ORDER BY `colA`',
   },
   {  # it may look odd, but this is the desired behaviour (mst)
    given => 'colA DESC',
    expects => ' ORDER BY colA DESC',
    expects_quoted => ' ORDER BY `colA DESC`',
   },
   {
    given => [qw/colA colB/],
    expects => ' ORDER BY colA, colB',
    expects_quoted => ' ORDER BY `colA`, `colB`',
   },
   {  # it may look odd, but this is the desired behaviour (mst)
    given => ['colA ASC', 'colB DESC'],
    expects => ' ORDER BY colA ASC, colB DESC',
    expects_quoted => ' ORDER BY `colA ASC`, `colB DESC`',
   },
   {
    given => {-asc => 'colA'},
    expects => ' ORDER BY colA ASC',
    expects_quoted => ' ORDER BY `colA` ASC',
   },
   {
    given => {-desc => 'colB'},
    expects => ' ORDER BY colB DESC',
    expects_quoted => ' ORDER BY `colB` DESC',
   },
   {
    given => [{-asc => 'colA'}, {-desc => 'colB'}],
    expects => ' ORDER BY colA ASC, colB DESC',
    expects_quoted => ' ORDER BY `colA` ASC, `colB` DESC',
   },
   {
    given => ['colA', {-desc => 'colB'}],
    expects => ' ORDER BY colA, colB DESC',
    expects_quoted => ' ORDER BY `colA`, `colB` DESC',
   },
   {
    given => undef,
    expects => '',
    expects_quoted => '',
   },
  );


plan tests => (scalar(@cases) * 2);

my $sql  = SQL::Abstract->new;
my $sqlq = SQL::Abstract->new({quote_char => '`'});

for my $case( @cases){
  is($sql->_order_by($case->{given}), $case->{expects});
  is($sqlq->_order_by($case->{given}), $case->{expects_quoted});
}
