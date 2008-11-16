#!/usr/bin/perl

use strict;
use warnings;
use Test::More;

use SQL::Abstract::Test import => ['is_same_sql_bind'];

use SQL::Abstract;

my $sql = SQL::Abstract->new;

my @data = (
    {
        user => 'nwiger',
        name => 'Nathan Wiger',
        phone => '123-456-7890',
        addr => 'Yeah, right',
        city => 'Milwalkee',
        state => 'Minnesota',
    },

    {
        user => 'jimbo',
        name => 'Jimbo Bobson',
        phone => '321-456-0987',
        addr => 'Yo Momma',
        city => 'Yo City',
        state => 'Minnesota',
    },

    {
        user => 'mr.hat',
        name => 'Mr. Garrison',
        phone => '123-456-7890',
        addr => undef,
        city => 'South Park',
        state => 'CO',
    },

    {
        user => 'kennyg',
        name => undef,
        phone => '1-800-Sucky-Sucky',
        addr => 'Mr. Garrison',
        city => undef,
        state => 'CO',
    },

    {
        user => 'barbara_streisand',
        name => 'MechaStreisand!',
        phone => 0,
        addr => -9230992340,
        city => 42,
        state => 'CO',
    },
);


plan tests => scalar(@data);

# Note to self: I have no idea what this does anymore
# It looks like a cool fucking segment of code though!
# I just wish I remembered writing it... :-\

my($sth, $stmt);
my($laststmt, $numfields);
for my $t (@data) {
      local $"=', ';

      $stmt = $sql->insert('yo_table', $t);
      my @val = $sql->values($t);
      $numfields ||= @val;

      ok((! $laststmt || $stmt eq $laststmt) && @val == $numfields
          && equal(\@val, [map { $t->{$_} } sort keys %$t])) or
              print "got\n",
                    "[$stmt] [@val]\n",
                    "instead of\n",
                    "[$t->{stmt}] [stuff]\n\n";
      $laststmt = $stmt;
}

sub equal {
      my ($a, $b) = @_;
      return 0 if @$a != @$b;
      for (my $i = 0; $i < $#{$a}; $i++) {
              next if (! defined($a->[$i])) && (! defined($b->[$i]));
              return 0 if $a->[$i] ne $b->[$i];
      }
      return 1;
}

