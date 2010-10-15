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

   is($sqlat->fill_in_placeholder($placeholders), q(;lolz-),
      'placeholders are populated correctly'
   );
}

{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(< >)],
   });

   is($sqlat->fill_in_placeholder($placeholders), q(<station>),
      'placeholders are populated correctly and in order'
   );
}


{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(' ')],
   });

   is $sqlat->format('SELECT ? as x, ? as y FROM Foo WHERE t > ? and z IN (?, ?, ?) ', ['frew', 'ribasushi', '2008-12-12', 1, 2, 3]),
   q[SELECT 'frew' as x, 'ribasushi' as y FROM Foo WHERE t > '2008-12-12' AND z IN ('1', '2', '3')], 'Complex placeholders work';
}

done_testing;
