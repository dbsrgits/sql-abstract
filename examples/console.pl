#!/sur/bin/env perl

use warnings;
use strict;

use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({ profile => 'console' });

my @sql = (
   "BEGIN WORK",
   "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'",
   "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'",
   "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'",
   "SELECT * LIMIT 5 OFFSET 5 FROM lolz ",
   "SELECT * LIMIT 5 5 FROM lolz ",
   "SELECT SKIP 5 FIRST 5 * FROM lolz ",
   "SELECT FIRST 5 SKIP 5 * FROM lolz ",
   "UPDATE session SET expires = ?  WHERE (id = ?)",
   "INSERT INTO Request (creation_date, is_private, owner_id, request) VALUES (? , ? , ? , ?)",
   "SELECT [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype] FROM [users_roles] [me] JOIN [roles] [role] ON [role].[id] = [me].[role_id] JOIN [roles_permissions] [role_permissions] ON [role_permissions].[role_id] = [role].[id] JOIN [permissions] [permission] ON [permission].[id] = [role_permissions].[permission_id] JOIN [permissionscreens] [permission_screens] ON [permission_screens].[permission_id] = [permission].[id] JOIN [screens] [screen] ON [screen].[id] = [permission_screens].[screen_id] WHERE ( [me].[user_id] = ? ) GROUP BY [screen].[id], [screen].[name], [screen].[section_id], [screen].[xtype]",
   "SELECT [status], [supplier_id], [ship_to_supplier_id], [request_by_user_id], [is_printed], [creation_date], [id], [date], [fob_state], [is_confirmed], [is_outside_process], [ship_via], [special_instructions], [when_shipped] FROM ( SELECT [status], [supplier_id], [ship_to_supplier_id], [request_by_user_id], [is_printed], [creation_date], [id], [date], [fob_state], [is_confirmed], [is_outside_process], [ship_via], [special_instructions], [when_shipped], ROW_NUMBER() OVER(  ORDER BY [me].[id] DESC ) AS [rno__row__index] FROM ( SELECT [me].[status], [me].[supplier_id], [me].[ship_to_supplier_id], [me].[request_by_user_id], [me].[is_printed], [me].[creation_date], [me].[id], [me].[date], [me].[fob_state], [me].[is_confirmed], [me].[is_outside_process], [me].[ship_via], [me].[special_instructions], [me].[when_shipped] FROM [PurchaseOrders] [me] WHERE ( [me].[status] = ? ) ) [me] ) [me] WHERE [rno__row__index] BETWEEN 1 AND 25",
   "SELECT me.id, me.name, me.creator_id, group_users.group_id, group_users.user_id, user.id, user.first_name, user.last_name, user.nickname, user.email, user.password, user.is_active, user.logins FROM Group me LEFT JOIN GroupUser group_users ON group_users.group_id = me.id LEFT JOIN User user ON user.id = group_users.user_id WHERE (me.creator_id = ?) ORDER BY name, group_users.group_id",
   "COMMIT",
   'ROLLBACK',
   'SAVEPOINT station',
   'ROLLBACK TO SAVEPOINT station',
   'RELEASE SAVEPOINT station',
   "SELECT COUNT( * ) FROM message_children me WHERE( ( me.phone_number NOT IN ( SELECT message_child.phone_number FROM blocked_destinations me JOIN message_children_status reason ON reason.id = me.reason_id JOIN message_children message_child ON message_child.id = reason.message_child_id) AND ( ( me.api_id IS NULL ) ) ) )"
);

print "\n\n'" . $sqlat->format($_) . "'\n" for @sql;

print "\n\n'" . $sqlat->format(
   "UPDATE session SET expires = ? WHERE (id = ?)", ['2010-12-02', 1]
) . "'\n";


print "\n\n'" . $sqlat->format(
 "SELECT raw_scores FROM ( SELECT raw_scores, ROW_NUMBER() OVER ( ORDER BY ( SELECT (1))) AS rno__row__index FROM ( SELECT rpt_score.raw_scores FROM users me JOIN access access ON access.userid = me.userid JOIN mgmt mgmt ON mgmt.mgmtid = access.mgmtid JOIN [order] orders ON orders.mgmtid = mgmt.mgmtid JOIN shop shops ON shops.orderno = orders.orderno JOIN rpt_scores rpt_score ON rpt_score.shopno = shops.shopno WHERE ( datecompleted IS NOT NULL AND ( (shops.datecompleted BETWEEN ? AND ?)  AND (type = ? AND me.userid = ?)))) rpt_score) rpt_score WHERE rno__row__index BETWEEN ? AND ? )", ['2009-10-01', '2009-10-08', 1, 'frew', 1, 1]
 ) . "'\n";

