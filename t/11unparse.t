use strict;
use warnings;

use Test::More;
use Test::Deep;
use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new;

cmp_deeply($sqlat->parse("SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'"), [ [ [ "SELECT", [ [ "LITERAL", [ "a, b, c" ] ] ] ], [ "FROM", [ [ "LITERAL", [ "foo" ] ] ] ] ], [ "WHERE", [ [ "AND", [ [ "=", [ [ "LITERAL", [ "foo.a" ] ], [ "LITERAL", [ 1 ] ] ] ], [ "LIKE", [ [ "LITERAL", [ "foo.b" ] ], [ "LITERAL", [ "'station'" ] ] ] ] ] ] ] ] ], 'simple statement parsed correctly');


cmp_deeply($sqlat->parse( "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'"), [ [ [ "SELECT", [ [ "LITERAL", [ "*" ] ] ] ], [ "FROM", [ [ "PAREN", [ [ [ "SELECT", [ [ "LITERAL", [ "*" ] ] ] ], [ "FROM", [ [ "LITERAL", [ "foobar" ] ] ] ] ] ] ] ] ] ], [ "WHERE", [ [ "AND", [ [ "=", [ [ "LITERAL", [ "foo.a" ] ], [ "LITERAL", [ 1 ] ] ] ], [ "LIKE", [ [ "LITERAL", [ "foo.b" ] ], [ "LITERAL", [ "'station'" ] ] ] ] ] ] ] ] ], 'subquery statement parsed correctly');

cmp_deeply($sqlat->parse("SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'"), [ [ [ "SELECT", [ [ "LITERAL", [ "*" ] ] ] ], [ "FROM", [ [ "LITERAL", [ "lolz" ] ] ] ] ], [ "WHERE", [ [ "AND", [ [ "PAREN", [ [ "=", [ [ "LITERAL", [ "foo.a" ] ], [ "LITERAL", [ 1 ] ] ] ] ] ], [ "LIKE", [ [ "LITERAL", [ "foo.b" ] ], [ "LITERAL", [ "'station'" ] ] ] ] ] ] ] ] ], 'simple statement with parens in where parsed correctly');

cmp_deeply($sqlat->parse( "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]"), [ [ [ [ [ [ [ [ [ [ [ [ [ [ "SELECT", [ [ "LITERAL", [ "[screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]" ] ] ] ], [ "FROM", [ [ "LITERAL", [ "[users_roles] [me]" ] ] ] ] ], [ "JOIN", [ [ "LITERAL", [ "[roles] [role]" ] ] ] ] ], [ "ON", [ [ "=", [ [ "LITERAL", [ "[role].[id]" ] ], [ "LITERAL", [ "[me].[role_id]" ] ] ] ] ] ] ], [ "JOIN", [ [ "LITERAL", [ "[roles_permissions] [role_permissions]" ] ] ] ] ], [ "ON", [ [ "=", [ [ "LITERAL", [ "[role_permissions].[role_id]" ] ], [ "LITERAL", [ "[role].[id]" ] ] ] ] ] ] ], [ "JOIN", [ [ "LITERAL", [ "[permissions] [permission]" ] ] ] ] ], [ "ON", [ [ "=", [ [ "LITERAL", [ "[permission].[id]" ] ], [ "LITERAL", [ "[role_permissions].[permission_id]" ] ] ] ] ] ] ], [ "JOIN", [ [ "LITERAL", [ "[permissionscreens] [permission_screens]" ] ] ] ] ], [ "ON", [ [ "=", [ [ "LITERAL", [ "[permission_screens].[permission_id]" ] ], [ "LITERAL", [ "[permission].[id]" ] ] ] ] ] ] ], [ "JOIN", [ [ "LITERAL", [ "[screens] [screen]" ] ] ] ] ], [ "ON", [ [ "=", [ [ "LITERAL", [ "[screen].[id]" ] ], [ "LITERAL", [ "[permission_screens].[screen_id]" ] ] ] ] ] ] ], [ "WHERE", [ [ "PAREN", [ [ "=", [ [ "LITERAL", [ "[me].[user_id]" ] ], [ "LITERAL", [ "?" ] ] ] ] ] ] ] ] ], [ "GROUP BY", [ [ "LITERAL", [ "[screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]" ] ] ] ] ],
   'real life statement 1 parsed correctly'
);

done_testing;
