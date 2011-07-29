#!/usr/bin/env perl

use Test::More;
use Test::Exception;

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
  "SELECT * FROM foo WHERE NOT EXISTS (SELECT bar FROM baz)",
  "SELECT * FROM (SELECT SUM (CASE WHEN me.artist = 'foo' THEN 1 ELSE 0 END AS artist_sum) FROM foobar) WHERE foo.a = 1 and foo.b LIKE 'station'",
  "SELECT COUNT( * ) FROM foo me JOIN bar rel_bar ON rel_bar.id_bar = me.fk_bar WHERE NOT EXISTS (SELECT inner_baz.id_baz FROM baz inner_baz WHERE ( ( inner_baz.fk_a != ? AND ( fk_bar = me.fk_bar AND name = me.name ) ) ) )",
);

for (@sql) {
  # Needs whitespace preservation in the AST to work, pending
  #local $SQL::Abstract::Test::mysql_functions = 1;
  is_same_sql ($sqlat->format($_), $_, sprintf 'roundtrip works (%s...)', substr $_, 0, 20);
}

# delete this test when mysql_functions gets implemented
my $sql = 'SELECT COUNT( * ), SUM( blah ) FROM foo';
is($sqlat->format($sql), $sql, 'Roundtripping to mysql-compatible paren. syntax');

lives_ok { $sqlat->unparse( $sqlat->parse( <<'EOS' ) ) } 'Able to parse/unparse grossly malformed sql';
SELECT
  (
    SELECT *, *  FROM EXISTS bar JOIN ON a = b
    NOT WHERE c !!= d
  ),
  NOT x,
  (
    SELECT * FROM bar WHERE NOT NOT EXISTS (SELECT 1)
  ),
WHERE NOT NOT 1 AND OR foo IN (1,2,,,3,,,),
GROUP BY bar

EOS

done_testing;
