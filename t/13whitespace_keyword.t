use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({
   newline => "\n",
   indent_string => " ",
   indent_amount => 1,
   indentmap => {
      select     => 0,
      where      => 1,
      from       => 2,
      join       => 3,
      on         => 4,
      'group by' => 5,
      'order by' => 6,
   },
});

for ( keys %{$sqlat->indentmap}) {
   my ($l, $r) = @{$sqlat->pad_keyword($_, 1)};
   is($r, '', "right is empty for $_");
   is($l, "\n " . ' ' x $sqlat->indentmap->{$_}, "left calculated correctly for $_" );
}

is($sqlat->pad_keyword('select', 0)->[0], '', 'Select gets no newline or indent for depth 0');

done_testing;
