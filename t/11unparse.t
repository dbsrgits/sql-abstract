use strict;
use warnings;

use Test::More;
use SQL::Abstract::Tree;

subtest no_formatting => sub {
   my $sqlat = SQL::Abstract::Tree->new;

   {
      my $sql = "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         "SELECT a, b, c FROM foo WHERE foo.a = 1 AND foo.b LIKE 'station' ";
      is($sqlat->format($sql), $expected_sql,
         'simple statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         "SELECT * FROM (SELECT * FROM foobar ) WHERE foo.a = 1 AND foo.b LIKE 'station' ";
      is($sqlat->format($sql), $expected_sql,
         'subquery statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'";
      my $expected_sql =
         "SELECT * FROM lolz WHERE (foo.a = 1) AND foo.b LIKE 'station' ";

      is($sqlat->format($sql), $expected_sql,
         'simple statement with parens in where formatted correctly'
      );
   }
   done_testing;
};

subtest console_monochrome => sub {
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
};

subtest html => sub {
   my $sqlat = SQL::Abstract::Tree->new({
      profile => 'html',
   });

   {
      my $sql = "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         qq{<span class="select">SELECT</span> a, b, c <br />\n} .
         qq{&nbsp;&nbsp;<span class="from">FROM</span> foo <br />\n} .
         qq{&nbsp;&nbsp;<span class="where">WHERE</span> foo.a = 1 AND foo.b LIKE 'station' };
      is($sqlat->format($sql), $expected_sql,
         'simple statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         qq{<span class="select">SELECT</span> * <br />\n} .
         qq{&nbsp;&nbsp;<span class="from">FROM</span> (<br />\n} .
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="select">SELECT</span> * <br />\n} .
         qq{&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class="from">FROM</span> foobar <br />\n} .
         qq{&nbsp;&nbsp;) <br />\n} .
         qq{&nbsp;&nbsp;<span class="where">WHERE</span> foo.a = 1 AND foo.b LIKE 'station' };

      is($sqlat->format($sql), $expected_sql,
         'subquery statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'";
      my $expected_sql =
         qq{<span class="select">SELECT</span> * <br />\n} .
         qq{&nbsp;&nbsp;<span class="from">FROM</span> lolz <br />\n} .
         qq{&nbsp;&nbsp;<span class="where">WHERE</span> (foo.a = 1) AND foo.b LIKE 'station' };

      is($sqlat->format($sql), $expected_sql,
         'simple statement with parens in where formatted correctly'
      );
   }
   done_testing;
};

subtest configuration => sub {
   my $sqlat = SQL::Abstract::Tree->new({
      profile => 'console_monochrome',
      indent_string => "\t",
      indent_amount => 1,
      newline => "\r\n",
   });

   {
      my $sql = "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         qq{SELECT a, b, c \r\n} .
         qq{\tFROM foo \r\n} .
         qq{\tWHERE foo.a = 1 AND foo.b LIKE 'station' };
      is($sqlat->format($sql), $expected_sql,
         'simple statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'";
      my $expected_sql =
         qq{SELECT * \r\n} .
         qq{\tFROM (\r\n} .
         qq{\t\tSELECT * \r\n} .
         qq{\t\t\tFROM foobar \r\n} .
         qq{\t) \r\n} .
         qq{\tWHERE foo.a = 1 AND foo.b LIKE 'station' };

      is($sqlat->format($sql), $expected_sql,
         'subquery statement formatted correctly'
      );
   }

   {
      my $sql = "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'";
      my $expected_sql =
         qq{SELECT * \r\n} .
         qq{\tFROM lolz \r\n} .
         qq{\tWHERE (foo.a = 1) AND foo.b LIKE 'station' };

      is($sqlat->format($sql), $expected_sql,
         'simple statement with parens in where formatted correctly'
      );
   }
   done_testing;
};

done_testing;
# stuff we want:
#    Max Width
#    Color coding (html)
