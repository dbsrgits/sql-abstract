#!/usr/bin/env perl

use Test::More;
use SQL::Abstract::Test import => ['is_same_sql'];
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new;

my @sql = (
  "INSERT INTO artist DEFAULT VALUES",
  "INSERT INTO artist VALUES ()",
  "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'",
  "SELECT COUNT( * ) FROM foo",
  "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a = 1 and foo.b LIKE 'station'",
  "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'",
  "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]",
);

for (@sql) {
  # Needs whitespace preservation in the AST to work, pending
  #local $SQL::Abstract::Test::mysql_functions = 1;
  is_same_sql ($sqlat->format($_), $_, sprintf 'roundtrip works (%s...)', substr $_, 0, 20);
}

# delete this test when mysql_functions gets implemented
my $sql = 'SELECT COUNT( * ) FROM foo';
is($sqlat->format($sql), $sql, 'Roundtripping to mysql-compatible paren. syntax');

done_testing;
