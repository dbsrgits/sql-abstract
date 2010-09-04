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

   {
      my $sql = "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]";
      my $expected_sql =
         "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ([me].[user_id] = ?) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] ";

      is($sqlat->format($sql), $expected_sql,
         'real life statement 1 formatted correctly'
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

   {
      my $sql = "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]";
      my $expected_sql =
         "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] \n".
         "  FROM [users_roles] [me] \n" .
         "  JOIN [roles] [role] \n" .
         "    ON [role].[id] = [me].[role_id] \n" .
         "  JOIN [roles_permissions] [role_permissions] \n" .
         "    ON [role_permissions].[role_id] = [role].[id] \n" .
         "  JOIN [permissions] [permission] \n" .
         "    ON [permission].[id] = [role_permissions].[permission_id] \n" .
         "  JOIN [permissionscreens] [permission_screens] \n" .
         "    ON [permission_screens].[permission_id] = [permission].[id] \n" .
         "  JOIN [screens] [screen] \n" .
         "    ON [screen].[id] = [permission_screens].[screen_id] \n" .
         "  WHERE ([me].[user_id] = ?) \n" .
         "  GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] ";

      my $gotten = $sqlat->format($sql);
      is($gotten, $expected_sql, 'real life statement 1 formatted correctly');
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

   {
      my $sql = "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]";
      my $expected_sql =
         qq{<span class="select">SELECT</span> [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] <br />\n}.
         qq{&nbsp;&nbsp;<span class="from">FROM</span> [users_roles] [me] <br />\n}.
         qq{&nbsp;&nbsp;<span class="join">JOIN</span> [roles] [role] <br />\n}.
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="on">ON</span> [role].[id] = [me].[role_id] <br />\n}.
         qq{&nbsp;&nbsp;<span class="join">JOIN</span> [roles_permissions] [role_permissions] <br />\n}.
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="on">ON</span> [role_permissions].[role_id] = [role].[id] <br />\n}.
         qq{&nbsp;&nbsp;<span class="join">JOIN</span> [permissions] [permission] <br />\n}.
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="on">ON</span> [permission].[id] = [role_permissions].[permission_id] <br />\n}.
         qq{&nbsp;&nbsp;<span class="join">JOIN</span> [permissionscreens] [permission_screens] <br />\n}.
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="on">ON</span> [permission_screens].[permission_id] = [permission].[id] <br />\n}.
         qq{&nbsp;&nbsp;<span class="join">JOIN</span> [screens] [screen] <br />\n}.
         qq{&nbsp;&nbsp;&nbsp;&nbsp;<span class="on">ON</span> [screen].[id] = [permission_screens].[screen_id] <br />\n}.
         qq{&nbsp;&nbsp;<span class="where">WHERE</span> ([me].[user_id] = ?) <br />\n}.
         qq{&nbsp;&nbsp;<span class="group-by">GROUP BY</span> [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] };

      my $gotten = $sqlat->format($sql);
      is($gotten, $expected_sql, 'real life statement 1 formatted correctly');
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

   {
      my $sql = "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]";
      my $expected_sql =
         "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] \r\n".
         "\tFROM [users_roles] [me] \r\n" .
         "\tJOIN [roles] [role] \r\n" .
         "\t\tON [role].[id] = [me].[role_id] \r\n" .
         "\tJOIN [roles_permissions] [role_permissions] \r\n" .
         "\t\tON [role_permissions].[role_id] = [role].[id] \r\n" .
         "\tJOIN [permissions] [permission] \r\n" .
         "\t\tON [permission].[id] = [role_permissions].[permission_id] \r\n" .
         "\tJOIN [permissionscreens] [permission_screens] \r\n" .
         "\t\tON [permission_screens].[permission_id] = [permission].[id] \r\n" .
         "\tJOIN [screens] [screen] \r\n" .
         "\t\tON [screen].[id] = [permission_screens].[screen_id] \r\n" .
         "\tWHERE ([me].[user_id] = ?) \r\n" .
         "\tGROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] ";

      my $gotten = $sqlat->format($sql);
      is($gotten, $expected_sql, 'real life statement 1 formatted correctly');
   }
   done_testing;
};

done_testing;
# stuff we want:
#    Max Width
#    placeholder substitution
