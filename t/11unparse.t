use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({
   profile => 'console_monochrome',
});

{
   my $sql = "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'";
   my $expected_sql =
      qq{SELECT a, b, c \n} .
      qq{  FROM foo \n} .
      qq{  WHERE foo.a = 1 AND foo.b LIKE 'station' };
   is($sqlat->format($sql), $expected_sql,
      'simple statement formatted correctly'
   );
}

{
   my $sql = "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'";
   my $expected_sql =
      qq{SELECT * \n} .
      qq{  FROM (\n} .
      qq{    SELECT * \n} .
      qq{      FROM foobar \n} .
      qq{  ) \n} .
      qq{  WHERE foo.a = 1 AND foo.b LIKE 'station' };

   is($sqlat->format($sql), $expected_sql,
      'subquery statement formatted correctly'
   );
}

{
   my $sql = "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'";
   my $expected_sql =
      qq{SELECT * \n} .
      qq{  FROM lolz \n} .
      qq{  WHERE (foo.a = 1) AND foo.b LIKE 'station' };

   is($sqlat->format($sql), $expected_sql,
      'simple statement with parens in where formatted correctly'
   );
}

done_testing;
# stuff we want:
#    Nested indentation
#    Max Width
#    Color coding (console)
#    Color coding (html)
