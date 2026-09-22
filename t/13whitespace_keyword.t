use strict;
use warnings;

use Test::More;
use Test::Warn;
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

# an indentmap without a newline must not warn (pad_keyword guards newline
# the same way _unparse does)
{
  my $no_newline = SQL::Abstract::Tree->new({ indentmap => { where => 1 } });
  warnings_are {
    is(
      $no_newline->unparse($no_newline->parse('SELECT a FROM foo WHERE x = 1')),
      'SELECT a FROM foo WHERE x = 1',
      'unparses correctly with an indentmap but no newline',
    );
  } [], 'no uninitialized-value warnings when newline is unset';
}

done_testing;
