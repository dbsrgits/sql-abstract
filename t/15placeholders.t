use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $placeholders = ['station', 'lolz'];

{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(; -)],
   });

   is($sqlat->fill_in_placeholder($placeholders), q(';lolz-'),
      'placeholders are populated correctly'
   );
}

{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(< >)],
   });

   is($sqlat->fill_in_placeholder($placeholders), q('<station>'),
      'placeholders are populated correctly and in order'
   );
}

done_testing;
