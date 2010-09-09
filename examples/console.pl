#!/sur/bin/env perl

use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({ profile => 'console' });

my @sql = (
   "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'",
   "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'",
   "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'",
   "UPDATE session SET expires = ?  WHERE (id = ?)",
   "INSERT INTO Request (creation_date, is_private, owner_id, request) VALUES (? , ? , ? , ?)",
   "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]",
   "SELECT [status], [supplier_id], [ship_to_supplier_id], [request_by_user_id], [is_printed], [creation_date], [id], [date], [fob_state], [is_confirmed], [is_outside_process], [ship_via], [special_instructions], [when_shipped] FROM ( SELECT [status], [supplier_id], [ship_to_supplier_id], [request_by_user_id], [is_printed], [creation_date], [id], [date], [fob_state], [is_confirmed], [is_outside_process], [ship_via], [special_instructions], [when_shipped], ROW_NUMBER() OVER(  ORDER BY [me].[id] DESC ) AS [rno__row__index] FROM ( SELECT [me].[status], [me].[supplier_id], [me].[ship_to_supplier_id], [me].[request_by_user_id], [me].[is_printed], [me].[creation_date], [me].[id], [me].[date], [me].[fob_state], [me].[is_confirmed], [me].[is_outside_process], [me].[ship_via], [me].[special_instructions], [me].[when_shipped] FROM [PurchaseOrders] [me] WHERE ( [me].[status] = ? ) ) [me] ) [me] WHERE [rno__row__index] BETWEEN 1 AND 25",
   "SELECT me.id, me.name, me.creator_id, group_users.group_id, group_users.user_id, user.id, user.first_name, user.last_name, user.nickname, user.email, user.password, user.is_active, user.logins FROM Group me LEFT JOIN GroupUser group_users ON group_users.group_id = me.id LEFT JOIN User user ON user.id = group_users.user_id WHERE (me.creator_id = ?) ORDER BY name, group_users.group_id",

);

print "\n\n'" . $sqlat->format($_) . "'\n" for @sql;

