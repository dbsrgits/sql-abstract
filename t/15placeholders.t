use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(; -)],
   });

   is($sqlat->fill_in_placeholder(['lolz']), q(;lolz-),
      'placeholders are populated correctly'
   );
}

{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(< >)],
   });

   is($sqlat->fill_in_placeholder(['station']), q(<station>),
      'placeholders are populated correctly and in order'
   );
}


{
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(' ')],
   });

   is $sqlat->format('SELECT ? AS x, ? AS y FROM Foo WHERE t > ? and z IN (?, ?, ?) ', [qw/frew ribasushi 2008-12-12 1 2 3/]),
   q[SELECT 'frew' AS x, 'ribasushi' AS y FROM Foo WHERE t > '2008-12-12' AND z IN ( '1', '2', '3' )], 'Complex placeholders work';
}

{
   # a legitimate 0 (or '0') bind value must not be dropped/blanked
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [qw(; -)],
   });

   is($sqlat->fill_in_placeholder([0]), q(;0-),
      'a numeric 0 bind value is preserved, not blanked'
   );
   is($sqlat->fill_in_placeholder(['0']), q(;0-),
      "a string '0' bind value is preserved, not blanked"
   );
}

{
   # an empty placeholder_surround means "no surround" and must not warn
   # (RT#117234)
   my $sqlat = SQL::Abstract::Tree->new({
      fill_in_placeholders => 1,
      placeholder_surround => [],
   });

   my @warnings;
   local $SIG{__WARN__} = sub { push @warnings, @_ };
   is($sqlat->format('SELECT x FROM t WHERE a = ?', [42]),
      'SELECT x FROM t WHERE a = 42',
      'empty placeholder_surround fills in the bare value'
   );
   is_deeply(\@warnings, [], 'empty placeholder_surround does not warn');
}

done_testing;
