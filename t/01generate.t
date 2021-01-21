use strict;
use warnings;
use Test::More;
use Test::Warn;
use Test::Exception;

use SQL::Abstract::Test import => [qw(is_same_sql_bind diag_where dumper)];

use SQL::Abstract;

#### WARNING ####
#
# -nest has been undocumented on purpose, but is still supported for the
# foreseable future. Do not rip out the -nest tests before speaking to
# someone on the DBIC mailing list or in irc.perl.org#dbix-class
#
#################

my @tests = (
      {
              func   => 'select',
              args   => ['test', '*'],
              stmt   => 'SELECT * FROM test',
              stmt_q => 'SELECT * FROM `test`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', [qw(one two three)]],
              stmt   => 'SELECT one, two, three FROM test',
              stmt_q => 'SELECT `one`, `two`, `three` FROM `test`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => 0 }, [qw/boom bada bing/]],
              stmt   => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY boom, bada, bing',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? ) ORDER BY `boom`, `bada`, `bing`',
              bind   => [0]
      },
      {
              func   => 'select',
              args   => ['test', '*', [ { a => 5 }, { b => 6 } ]],
              stmt   => 'SELECT * FROM test WHERE ( ( a = ? ) OR ( b = ? ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( `a` = ? ) OR ( `b` = ? ) )',
              bind   => [5,6]
      },
      {
              func   => 'select',
              args   => ['test', '*', undef, ['id']],
              stmt   => 'SELECT * FROM test ORDER BY id',
              stmt_q => 'SELECT * FROM `test` ORDER BY `id`',
              bind   => []
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => 'boom' } , ['id']],
              stmt   => 'SELECT * FROM test WHERE ( a = ? ) ORDER BY id',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? ) ORDER BY `id`',
              bind   => ['boom']
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => ['boom', 'bang'] }],
              stmt   => 'SELECT * FROM test WHERE ( ( ( a = ? ) OR ( a = ? ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( ( `a` = ? ) OR ( `a` = ? ) ) )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => { '!=', 'boom' } }],
              stmt   => 'SELECT * FROM test WHERE ( a != ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` != ? )',
              bind   => ['boom']
      },
      {
              # this is maybe wrong but a single arg doesn't get quoted
              func   => 'select',
              args   => ['test', 'id', { a => { '!=', 'boom' } }],
              stmt   => 'SELECT id FROM test WHERE ( a != ? )',
              stmt_q => 'SELECT id FROM `test` WHERE ( `a` != ? )',
              bind   => ['boom']
      },
      {
              func   => 'update',
              args   => ['test', {a => 'boom'}, {a => undef}],
              stmt   => 'UPDATE test SET a = ? WHERE ( a IS NULL )',
              stmt_q => 'UPDATE `test` SET `a` = ? WHERE ( `a` IS NULL )',
              bind   => ['boom']
      },
      {
              func   => 'update',
              args   => ['test', {a => undef }, {a => 'boom'}],
              stmt   => 'UPDATE test SET a = ? WHERE ( a = ? )',
              stmt_q => 'UPDATE `test` SET `a` = ? WHERE ( `a` = ? )',
              bind   => [undef,'boom']
      },
      {
              func   => 'update',
              args   => ['test', {a => 'boom'}, { a => {'!=', "bang" }} ],
              stmt   => 'UPDATE test SET a = ? WHERE ( a != ? )',
              stmt_q => 'UPDATE `test` SET `a` = ? WHERE ( `a` != ? )',
              bind   => ['boom', 'bang']
      },
      {
              func   => 'update',
              args   => ['test', {'a-funny-flavored-candy' => 'yummy', b => 'oops'}, { a42 => "bang" }],
              stmt   => 'UPDATE test SET a-funny-flavored-candy = ?, b = ? WHERE ( a42 = ? )',
              stmt_q => 'UPDATE `test` SET `a-funny-flavored-candy` = ?, `b` = ? WHERE ( `a42` = ? )',
              bind   => ['yummy', 'oops', 'bang']
      },
      {
              func   => 'delete',
              args   => ['test', {requestor => undef}],
              stmt   => 'DELETE FROM test WHERE ( requestor IS NULL )',
              stmt_q => 'DELETE FROM `test` WHERE ( `requestor` IS NULL )',
              bind   => []
      },
      {
              func   => 'delete',
              args   => [[qw/test1 test2 test3/],
                         { 'test1.field' => \'!= test2.field',
                            user => {'!=','nwiger'} },
                        ],
              stmt   => 'DELETE FROM test1, test2, test3 WHERE ( test1.field != test2.field AND user != ? )',
              stmt_q => 'DELETE FROM `test1`, `test2`, `test3` WHERE ( `test1`.`field` != test2.field AND `user` != ? )',  # test2.field is a literal value, cannnot be quoted.
              bind   => ['nwiger']
      },
      {
              func   => 'select',
              args   => [[\'test1', 'test2'], '*', { 'test1.a' => 'boom' } ],
              stmt   => 'SELECT * FROM test1, test2 WHERE ( test1.a = ? )',
              stmt_q => 'SELECT * FROM test1, `test2` WHERE ( `test1`.`a` = ? )',
              bind   => ['boom']
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt   => 'INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`, `c`, `d`, `e`) VALUES (?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [1..30]],
              stmt   => 'INSERT INTO test VALUES ('.join(', ', ('?')x30).')',
              stmt_q => 'INSERT INTO `test` VALUES ('.join(', ', ('?')x30).')',
              bind   => [1..30],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/, undef]],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4 5/, undef],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}],
              stmt   => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?, `c` = ?, `d` = ?, `e` = ?',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => 5}, {a => {'in', [1..5]}}],
              stmt   => 'UPDATE test SET a = ?, b = ?, c = ?, d = ?, e = ? WHERE ( a IN ( ?, ?, ?, ?, ? ) )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?, `c` = ?, `d` = ?, `e` = ? WHERE ( `a` IN ( ?, ?, ?, ?, ? ) )',
              bind   => [qw/1 2 3 4 5 1 2 3 4 5/],
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = to_date(?, \'MM/DD/YY\') WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = to_date(?, \'MM/DD/YY\') WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [qw(1 02/02/02 1 2)],
      },
      {
              func   => 'insert',
              args   => ['test.table', {high_limit => \'max(all_limits)', low_limit => 4} ],
              stmt   => 'INSERT INTO test.table (high_limit, low_limit) VALUES (max(all_limits), ?)',
              stmt_q => 'INSERT INTO `test`.`table` (`high_limit`, `low_limit`) VALUES (max(all_limits), ?)',
              bind   => ['4'],
      },
      {
              func   => 'insert',
              args   => ['test.table', [ \'max(all_limits)', 4 ] ],
              stmt   => 'INSERT INTO test.table VALUES (max(all_limits), ?)',
              stmt_q => 'INSERT INTO `test`.`table` VALUES (max(all_limits), ?)',
              bind   => ['4'],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test.table', {one => 2, three => 4, five => 6} ],
              stmt   => 'INSERT INTO test.table (five, one, three) VALUES (?, ?, ?)',
              stmt_q => 'INSERT INTO `test`.`table` (`five`, `one`, `three`) VALUES (?, ?, ?)',
              bind   => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns', case => 'lower'},
              args   => ['test.table', [qw/one two three/], {one => 2, three => 4, five => 6} ],
              stmt   => 'select one, two, three from test.table where ( five = ? and one = ? and three = ? )',
              stmt_q => 'select `one`, `two`, `three` from `test`.`table` where ( `five` = ? and `one` = ? and `three` = ? )',
              bind   => [['five', 6], ['one', 2], ['three', 4]],  # alpha order, man...
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns', cmp => 'like'},
              args   => ['testin.table2', {One => 22, Three => 44, FIVE => 66},
                                          {Beer => 'is', Yummy => '%YES%', IT => ['IS','REALLY','GOOD']}],
              stmt   => 'UPDATE testin.table2 SET FIVE = ?, One = ?, Three = ? WHERE '
                       . '( Beer LIKE ? AND ( ( IT LIKE ? ) OR ( IT LIKE ? ) OR ( IT LIKE ? ) ) AND Yummy LIKE ? )',
              stmt_q => 'UPDATE `testin`.`table2` SET `FIVE` = ?, `One` = ?, `Three` = ? WHERE '
                       . '( `Beer` LIKE ? AND ( ( `IT` LIKE ? ) OR ( `IT` LIKE ? ) OR ( `IT` LIKE ? ) ) AND `Yummy` LIKE ? )',
              bind   => [['FIVE', 66], ['One', 22], ['Three', 44], ['Beer','is'],
                         ['IT','IS'], ['IT','REALLY'], ['IT','GOOD'], ['Yummy','%YES%']],
      },
      {
              func   => 'select',
              args   => ['test', '*', {priority => [ -and => {'!=', 2}, { -not_like => '3%'} ]}],
              stmt   => 'SELECT * FROM test WHERE ( ( ( priority != ? ) AND ( priority NOT LIKE ? ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( ( ( `priority` != ? ) AND ( `priority` NOT LIKE ? ) ) )',
              bind   => [qw(2 3%)],
      },
      {
              func   => 'select',
              args   => ['Yo Momma', '*', { user => 'nwiger',
                                       -nest => [ workhrs => {'>', 20}, geo => 'ASIA' ] }],
              stmt   => 'SELECT * FROM Yo Momma WHERE ( ( ( workhrs > ? ) OR ( geo = ? ) ) AND user = ? )',
              stmt_q => 'SELECT * FROM `Yo Momma` WHERE ( ( ( `workhrs` > ? ) OR ( `geo` = ? ) ) AND `user` = ? )',
              bind   => [qw(20 ASIA nwiger)],
      },
      {
              func   => 'update',
              args   => ['taco_punches', { one => 2, three => 4 },
                                         { bland => [ -and => {'!=', 'yes'}, {'!=', 'YES'} ],
                                           tasty => { '!=', [qw(yes YES)] },
                                           -nest => [ face => [ -or => {'=', 'mr.happy'}, {'=', undef} ] ] },
                        ],
              warns  => qr/\QA multi-element arrayref as an argument to the inequality op '!=' is technically equivalent to an always-true 1=1/,

              stmt   => 'UPDATE taco_punches SET one = ?, three = ? WHERE ( ( ( ( ( face = ? ) OR ( face IS NULL ) ) ) )'
                      . ' AND ( ( bland != ? ) AND ( bland != ? ) ) AND ( ( tasty != ? ) OR ( tasty != ? ) ) )',
              stmt_q => 'UPDATE `taco_punches` SET `one` = ?, `three` = ? WHERE ( ( ( ( ( `face` = ? ) OR ( `face` IS NULL ) ) ) )'
                      . ' AND ( ( `bland` != ? ) AND ( `bland` != ? ) ) AND ( ( `tasty` != ? ) OR ( `tasty` != ? ) ) )',
              bind   => [qw(2 4 mr.happy yes YES yes YES)],
      },
      {
              func   => 'select',
              args   => ['jeff', '*', { name => {'ilike', '%smith%', -not_in => ['Nate','Jim','Bob','Sally']},
                                       -nest => [ -or => [ -and => [age => { -between => [20,30] }, age => {'!=', 25} ],
                                                                   yob => {'<', 1976} ] ] } ],
              stmt   => 'SELECT * FROM jeff WHERE ( ( ( ( ( ( ( age BETWEEN ? AND ? ) AND ( age != ? ) ) ) OR ( yob < ? ) ) ) )'
                      . ' AND name NOT IN ( ?, ?, ?, ? ) AND name ILIKE ? )',
              stmt_q => 'SELECT * FROM `jeff` WHERE ( ( ( ( ( ( ( `age` BETWEEN ? AND ? ) AND ( `age` != ? ) ) ) OR ( `yob` < ? ) ) ) )'
                      . ' AND `name` NOT IN ( ?, ?, ?, ? ) AND `name` ILIKE ? )',
              bind   => [qw(20 30 25 1976 Nate Jim Bob Sally %smith%)]
      },
      {
              func   => 'update',
              args   => ['fhole', {fpoles => 4}, [
                          { race => [qw/-or black white asian /] },
                          { -nest => { firsttime => [-or => {'=','yes'}, undef] } },
                          { -and => [ { firstname => {-not_like => 'candace'} }, { lastname => {-in => [qw(jugs canyon towers)] } } ] },
                        ] ],
              stmt   => 'UPDATE fhole SET fpoles = ? WHERE ( ( ( ( ( ( ( race = ? ) OR ( race = ? ) OR ( race = ? ) ) ) ) ) )'
                      . ' OR ( ( ( ( firsttime = ? ) OR ( firsttime IS NULL ) ) ) ) OR ( ( ( firstname NOT LIKE ? ) ) AND ( lastname IN (?, ?, ?) ) ) )',
              stmt_q => 'UPDATE `fhole` SET `fpoles` = ? WHERE ( ( ( ( ( ( ( `race` = ? ) OR ( `race` = ? ) OR ( `race` = ? ) ) ) ) ) )'
                      . ' OR ( ( ( ( `firsttime` = ? ) OR ( `firsttime` IS NULL ) ) ) ) OR ( ( ( `firstname` NOT LIKE ? ) ) AND ( `lastname` IN( ?, ?, ? )) ) )',
              bind   => [qw(4 black white asian yes candace jugs canyon towers)]
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [qw(1 02/02/02)],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", '02/02/02']}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => ['02/02/02'],
      },
      {
              func   => 'insert',
              new    => {array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, ?)',
              bind   => [1, [1, 1, 2, 3, 5, 8]],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns', array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, ?)',
              bind   => [[a => 1], [b => [1, 1, 2, 3, 5, 8]]],
      },
      {
              func   => 'update',
              new    => {array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'UPDATE test SET a = ?, b = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?',
              bind   => [1, [1, 1, 2, 3, 5, 8]],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns', array_datatypes => 1},
              args   => ['test', {a => 1, b => [1, 1, 2, 3, 5, 8]}],
              stmt   => 'UPDATE test SET a = ?, b = ?',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = ?',
              bind   => [[a => 1], [b => [1, 1, 2, 3, 5, 8]]],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'>', \'1 + 1'}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a > 1 + 1 AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` > 1 + 1 AND `b` = ? )',
              bind   => [8],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => ['02/02/02', 8],
      },
      { #TODO in SQLA >= 2.0 it will die instead (we kept this just because old SQLA passed it through)
              func   => 'insert',
              args   => ['test', {a => 1, b => 2, c => 3, d => 4, e => { answer => 42 }}],
              stmt   => 'INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`, `c`, `d`, `e`) VALUES (?, ?, ?, ?, ?)',
              bind   => [qw/1 2 3 4/, { answer => 42}],
              warns  => qr/HASH ref as bind value in insert is not supported/i,
      },
      {
              func   => 'update',
              args   => ['test', {a => 1, b => \["42"]}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = 42 WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = 42 WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [qw(1 1 2)],
      },
      {
              func   => 'insert',
              args   => ['test', {a => 1, b => \["42"]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, 42)',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, 42)',
              bind   => [qw(1)],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => \["= 42"], b => 1}],
              stmt   => q{SELECT * FROM test WHERE ( a = 42 ) AND (b = ? )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = 42 ) AND ( `b` = ? )},
              bind   => [qw(1)],
      },
      {
              func   => 'select',
              args   => ['test', '*', { a => {'<' => \["42"]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < 42 AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < 42 AND `b` = ? )',
              bind   => [qw(8)],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [[a => '1'], [dummy => '02/02/02']],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}, {a => {'between', [1,2]}}],
              stmt   => 'UPDATE test SET a = ?, b = to_date(?, \'MM/DD/YY\') WHERE ( a BETWEEN ? AND ? )',
              stmt_q => 'UPDATE `test` SET `a` = ?, `b` = to_date(?, \'MM/DD/YY\') WHERE ( `a` BETWEEN ? AND ? )',
              bind   => [[a => '1'], [dummy => '02/02/02'], [a => '1'], [a => '2']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => [[dummy => '02/02/02']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", [dummy => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => [[dummy => '02/02/02'], [b => 8]],
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}],
              throws => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, {a => {'between', [1,2]}}],
              throws => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", '02/02/02']}],
              throws => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", '02/02/02']}, b => 8 }],
              throws => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'select',
              args   => ['test', '*', { foo => { '>=' => [] }} ],
              throws => qr/\Qoperator '>=' applied on an empty array (field 'foo')/,
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {-in => \["(SELECT d FROM to_date(?, 'MM/DD/YY') AS d)", [dummy => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a IN (SELECT d FROM to_date(?, \'MM/DD/YY\') AS d) AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IN (SELECT d FROM to_date(?, \'MM/DD/YY\') AS d) AND `b` = ? )',
              bind   => [[dummy => '02/02/02'], [b => 8]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {-in => \["(SELECT d FROM to_date(?, 'MM/DD/YY') AS d)", '02/02/02']}, b => 8 }],
              throws => qr/bindtype 'columns' selected, you need to pass: \[column_name => bind_value\]/,
      },
      {
              func   => 'insert',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}],
              stmt   => 'INSERT INTO test (a, b) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              stmt_q => 'INSERT INTO `test` (`a`, `b`) VALUES (?, to_date(?, \'MM/DD/YY\'))',
              bind   => [[a => '1'], [{dummy => 1} => '02/02/02']],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns'},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']], c => { -lower => 'foo' }}, {a => {'between', [1,2]}}],
              stmt   => "UPDATE test SET a = ?, b = to_date(?, 'MM/DD/YY'), c = LOWER(?) WHERE ( a BETWEEN ? AND ? )",
              stmt_q => "UPDATE `test` SET `a` = ?, `b` = to_date(?, 'MM/DD/YY'), `c` = LOWER(?) WHERE ( `a` BETWEEN ? AND ? )",
              bind   => [[a => '1'], [{dummy => 1} => '02/02/02'], [c => 'foo'], [a => '1'], [a => '2']],
      },
      {
              func   => 'update',
              new    => {bindtype => 'columns',restore_old_unop_handling => 1},
              args   => ['test', {a => 1, b => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']], c => { -lower => 'foo' }}, {a => {'between', [1,2]}}],
              stmt   => "UPDATE test SET a = ?, b = to_date(?, 'MM/DD/YY'), c = LOWER ? WHERE ( a BETWEEN ? AND ? )",
              stmt_q => "UPDATE `test` SET `a` = ?, `b` = to_date(?, 'MM/DD/YY'), `c` = LOWER ? WHERE ( `a` BETWEEN ? AND ? )",
              bind   => [[a => '1'], [{dummy => 1} => '02/02/02'], [c => 'foo'], [a => '1'], [a => '2']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => \["= to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}],
              stmt   => q{SELECT * FROM test WHERE ( a = to_date(?, 'MM/DD/YY') )},
              stmt_q => q{SELECT * FROM `test` WHERE ( `a` = to_date(?, 'MM/DD/YY') )},
              bind   => [[{dummy => 1} => '02/02/02']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { a => {'<' => \["to_date(?, 'MM/DD/YY')", [{dummy => 1} => '02/02/02']]}, b => 8 }],
              stmt   => 'SELECT * FROM test WHERE ( a < to_date(?, \'MM/DD/YY\') AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` < to_date(?, \'MM/DD/YY\') AND `b` = ? )',
              bind   => [[{dummy => 1} => '02/02/02'], [b => 8]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', { -or => [ -and => [ a => 'a', b => 'b' ], -and => [ c => 'c', d => 'd' ]  ]  }],
              stmt   => 'SELECT * FROM test WHERE ( a = ? AND b = ? ) OR ( c = ? AND d = ?  )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? AND `b` = ?  ) OR ( `c` = ? AND `d` = ? )',
              bind   => [[a => 'a'], [b => 'b'], [ c => 'c'],[ d => 'd']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ { a => 1, b => 1}, [ a => 2, b => 2] ] ],
              stmt   => 'SELECT * FROM test WHERE ( a = ? AND b = ? ) OR ( a = ? OR b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? AND `b` = ? ) OR ( `a` = ? OR `b` = ? )',
              bind   => [[a => 1], [b => 1], [ a => 2], [ b => 2]],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ [ a => 1, b => 1], { a => 2, b => 2 } ] ],
              stmt   => 'SELECT * FROM test WHERE ( a = ? OR b = ? ) OR ( a = ? AND b = ? )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` = ? OR `b` = ? ) OR ( `a` = ? AND `b` = ? )',
              bind   => [[a => 1], [b => 1], [ a => 2], [ b => 2]],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => 'id' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => 'id, foo, bar' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id, foo, bar`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => [qw(id  foo  bar) ] }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING `id`, `foo`, `bar`',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => \'id, foo, bar' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING id, foo, bar',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'insert',
              args   => ['test', [qw/1 2 3 4 5/], { returning => \'id' }],
              stmt   => 'INSERT INTO test VALUES (?, ?, ?, ?, ?) RETURNING id',
              stmt_q => 'INSERT INTO `test` VALUES (?, ?, ?, ?, ?) RETURNING id',
              bind   => [qw/1 2 3 4 5/],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns'},
              args   => ['test', '*', [ Y => { '=' => { -max => { -LENGTH => { -min => 'x' } } } } ] ],
              stmt   => 'SELECT * FROM test WHERE ( Y = ( MAX( LENGTH( MIN(?) ) ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `Y` = ( MAX( LENGTH( MIN(?) ) ) ) )',
              bind   => [[Y => 'x']],
      },
      {
              func   => 'select',
              new    => {bindtype => 'columns',restore_old_unop_handling => 1},
              args   => ['test', '*', [ Y => { '=' => { -max => { -LENGTH => { -min => 'x' } } } } ] ],
              stmt   => 'SELECT * FROM test WHERE ( Y = ( MAX( LENGTH( MIN ? ) ) ) )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `Y` = ( MAX( LENGTH( MIN ? ) ) ) )',
              bind   => [[Y => 'x']],
      },
      {
              func => 'select',
              args => ['test', '*', { a => { '=' => undef }, b => { -is => undef }, c => { -like => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NULL AND b IS NULL AND c IS NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NULL AND `b` IS NULL AND `c` IS NULL )',
              bind => [],
              warns => qr/\QSupplying an undefined argument to 'LIKE' is deprecated/,
      },
      {
              func => 'select',
              args => ['test', '*', { a => { '!=' => undef }, b => { -is_not => undef }, c => { -not_like => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NOT NULL AND b IS NOT  NULL AND c IS NOT  NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NOT  NULL AND `b` IS NOT  NULL AND `c` IS NOT  NULL )',
              bind => [],
              warns => qr/\QSupplying an undefined argument to 'NOT LIKE' is deprecated/,
      },
      {
              func => 'select',
              args => ['test', '*', { a => { IS => undef }, b => { LIKE => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NULL AND b IS NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NULL AND `b` IS NULL )',
              bind => [],
              warns => qr/\QSupplying an undefined argument to 'LIKE' is deprecated/,
      },
      {
              func => 'select',
              args => ['test', '*', { a => { 'IS NOT' => undef }, b => { 'NOT LIKE' => undef } }],
              stmt => 'SELECT * FROM test WHERE ( a IS NOT NULL AND b IS NOT  NULL )',
              stmt_q => 'SELECT * FROM `test` WHERE ( `a` IS NOT  NULL AND `b` IS NOT  NULL )',
              bind => [],
              warns => qr/\QSupplying an undefined argument to 'NOT LIKE' is deprecated/,
      },
      {
              func => 'select',
              args => ['`test``table`', ['`test``column`']],
              stmt => 'SELECT `test``column` FROM `test``table`',
              stmt_q => 'SELECT ```test````column``` FROM ```test````table```',
              bind => [],
      },
      {
              func => 'select',
              args => ['`test\\`table`', ['`test`\\column`']],
              stmt => 'SELECT `test`\column` FROM `test\`table`',
              stmt_q => 'SELECT `\`test\`\\\\column\`` FROM `\`test\\\\\`table\``',
              esc  => '\\',
              bind => [],
      },
      {
              func => 'update',
              args => ['mytable', { foo => 42 }, { baz => 32 }, { returning => 'id' }],
              stmt => 'UPDATE mytable SET foo = ? WHERE baz = ? RETURNING id',
              stmt_q => 'UPDATE `mytable` SET `foo` = ? WHERE `baz` = ? RETURNING `id`',
              bind => [42, 32],
      },
      {
              func => 'update',
              args => ['mytable', { foo => 42 }, { baz => 32 }, { returning => \'*' }],
              stmt => 'UPDATE mytable SET foo = ? WHERE baz = ? RETURNING *',
              stmt_q => 'UPDATE `mytable` SET `foo` = ? WHERE `baz` = ? RETURNING *',
              bind => [42, 32],
      },
      {
              func => 'update',
              args => ['mytable', { foo => 42 }, { baz => 32 }, { returning => ['id','created_at'] }],
              stmt => 'UPDATE mytable SET foo = ? WHERE baz = ? RETURNING id, created_at',
              stmt_q => 'UPDATE `mytable` SET `foo` = ? WHERE `baz` = ? RETURNING `id`, `created_at`',
              bind => [42, 32],
      },
      {
              func   => 'delete',
              args   => ['test', {requestor => undef}, {returning => 'id'}],
              stmt   => 'DELETE FROM test WHERE ( requestor IS NULL ) RETURNING id',
              stmt_q => 'DELETE FROM `test` WHERE ( `requestor` IS NULL ) RETURNING `id`',
              bind   => []
      },
      {
              func   => 'delete',
              args   => ['test', {requestor => undef}, {returning => \'*'}],
              stmt   => 'DELETE FROM test WHERE ( requestor IS NULL ) RETURNING *',
              stmt_q => 'DELETE FROM `test` WHERE ( `requestor` IS NULL ) RETURNING *',
              bind   => []
      },
      {
              func   => 'delete',
              args   => ['test', {requestor => undef}, {returning => ['id', 'created_at']}],
              stmt   => 'DELETE FROM test WHERE ( requestor IS NULL ) RETURNING id, created_at',
              stmt_q => 'DELETE FROM `test` WHERE ( `requestor` IS NULL ) RETURNING `id`, `created_at`',
              bind   => []
      },
      {
              func   => 'delete',
              args   => ['test', \[ undef ] ],
              stmt   => 'DELETE FROM test',
              stmt_q => 'DELETE FROM `test`',
              bind   => []
      },
);

# check is( not) => undef
for my $op (qw(not is is_not), 'is not') {
  (my $sop = uc $op) =~ s/_/ /gi;

  $sop = 'IS NOT' if $sop eq 'NOT';

  for my $uc (0, 1) {
    for my $prefix ('', '-') {
      push @tests, {
        func => 'where',
        args => [{ a => { ($prefix . ($uc ? uc $op : lc $op) ) => undef } }],
        stmt => "WHERE a $sop NULL",
        stmt_q => "WHERE `a` $sop NULL",
        bind => [],
      };
    }
  }
}

# check single-element inequality ops for no warnings
for my $op (qw(!= <>)) {
  for my $val (undef, 42) {
    push @tests, {
      func => 'where',
      args => [ { x => { "$_$op" => [ $val ] } } ],
      stmt => "WHERE x " . ($val ? "$op ?" : 'IS NOT NULL'),
      stmt_q => "WHERE `x` " . ($val ? "$op ?" : 'IS NOT NULL'),
      bind => [ $val || () ],
    } for ('', '-');  # with and without -
  }
}

# check single-element not-like ops for no warnings, and NULL exception
# (the last two "is not X" are a weird syntax, but mebbe a dialect...)
for my $op (qw(not_like not_rlike), 'not like', 'not rlike', 'is not like','is not rlike') {
  (my $sop = uc $op) =~ s/_/ /gi;

  for my $val (undef, 42) {
    push @tests, {
      func => 'where',
      args => [ { x => { "$_$op" => [ $val ] } } ],
      $val ? (
        stmt => "WHERE x $sop ?",
        stmt_q => "WHERE `x` $sop ?",
        bind => [ $val ],
      ) : (
        stmt => "WHERE x IS NOT NULL",
        stmt_q => "WHERE `x` IS NOT NULL",
        bind => [],
        warns => qr/\QSupplying an undefined argument to '$sop' is deprecated/,
      ),
    } for ('', '-');  # with and without -
  }
}

# check all multi-element inequality/not-like ops for warnings
for my $op (qw(!= <> not_like not_rlike), 'not like', 'not rlike', 'is not like','is not rlike') {
  (my $sop = uc $op) =~ s/_/ /gi;

  push @tests, {
    func => 'where',
    args => [ { x => { "$_$op" => [ 42, 69 ] } } ],
    stmt => "WHERE x $sop ? OR x $sop ?",
    stmt_q => "WHERE `x` $sop ? OR `x` $sop ?",
    bind => [ 42, 69 ],
    warns  => qr/\QA multi-element arrayref as an argument to the inequality op '$sop' is technically equivalent to an always-true 1=1/,
  } for ('', '-');  # with and without -
}

# check all like/not-like ops for empty-arrayref warnings
for my $op (qw(like rlike not_like not_rlike), 'not like', 'not rlike', 'is like', 'is not like', 'is rlike', 'is not rlike') {
  (my $sop = uc $op) =~ s/_/ /gi;

  push @tests, {
    func => 'where',
    args => [ { x => { "$_$op" => [] } } ],
    stmt => ( $sop =~ /NOT/ ? "WHERE 1=1" : "WHERE 0=1" ),
    stmt_q => ( $sop =~ /NOT/ ? "WHERE 1=1" : "WHERE 0=1" ),
    bind => [],
    warns  => qr/\QSupplying an empty arrayref to '$sop' is deprecated/,
  } for ('', '-');  # with and without -
}

# check emtpty-lhs in a hashpair and arraypair
for my $lhs (undef, '') {
  no warnings 'uninitialized';

##
## hard exceptions - never worked
  for my $where_arg (
    ( map { $_, { @$_ } }
      [ $lhs => "foo" ],
      [ $lhs => { "=" => "bozz" } ],
      [ $lhs => { "=" => \"bozz" } ],
      [ $lhs => { -max => \"bizz" } ],
    ),
    [ -and => { $lhs => "baz" }, bizz => "buzz" ],
    [ foo => "bar", { $lhs => "baz" }, bizz => "buzz" ],
    { foo => "bar", -or => { $lhs => "baz" } },

    # the hashref forms of these work sadly - check for warnings below
    { foo => "bar", -and => [ $lhs => \"baz" ], bizz => "buzz" },
    { foo => "bar", -or => [ $lhs => \"baz" ], bizz => "buzz" },
    [ foo => "bar", [ $lhs => \"baz" ], bizz => "buzz" ],
    [ foo => "bar", $lhs => \"baz", bizz => "buzz" ],
    [ foo => "bar", $lhs => \["baz"], bizz => "buzz" ],
    [ $lhs => \"baz" ],
    [ $lhs => \["baz"] ],
  ) {
    push @tests, {
      func => 'where',
      args => [ $where_arg ],
      throws  => qr/\QSupplying an empty left hand side argument is not supported/,
    };
  }

##
## deprecations - sorta worked, likely abused by folks
  for my $where_arg (
    # the arrayref forms of this never worked and throw above
    { foo => "bar", -or => { $lhs => \"baz" }, bizz => "buzz" },
    { foo => "bar", -and => { $lhs => \"baz" }, bizz => "buzz" },
    { foo => "bar", $lhs => \"baz", bizz => "buzz" },
    { foo => "bar", $lhs => \["baz"], bizz => "buzz" },
  ) {
    push @tests, {
      func    => 'where',
      args    => [ $where_arg ],
      stmt    => 'WHERE baz AND bizz = ? AND foo = ?',
      stmt_q  => 'WHERE baz AND `bizz` = ? AND `foo` = ?',
      bind    => [qw( buzz bar )],
      warns   => qr/\QHash-pairs consisting of an empty string with a literal are deprecated/,
    };
  }

  for my $where_arg (
    { $lhs => \"baz" },
    { $lhs => \["baz"] },
  ) {
    push @tests, {
      func    => 'where',
      args    => [ $where_arg ],
      stmt    => 'WHERE baz',
      stmt_q  => 'WHERE baz',
      bind    => [],
      warns   => qr/\QHash-pairs consisting of an empty string with a literal are deprecated/,
    }
  }
}

# check false lhs, silly but possible
{
  for my $where_arg (
    [ { 0 => "baz" }, bizz => "buzz", foo => "bar" ],
    [ -or => { foo => "bar", -or => { 0 => "baz" }, bizz => "buzz" } ],
  ) {
    push @tests, {
      func    => 'where',
      args    => [ $where_arg ],
      stmt    => 'WHERE 0 = ? OR bizz = ? OR foo = ?',
      stmt_q  => 'WHERE `0` = ? OR `bizz` = ? OR `foo` = ?',
      bind    => [qw( baz buzz bar )],
    };
  }

  for my $where_arg (
    { foo => "bar", -and => [ 0 => \"= baz" ], bizz => "buzz" },
    { foo => "bar", -or => [ 0 => \"= baz" ], bizz => "buzz" },

    { foo => "bar", -and => { 0 => \"= baz" }, bizz => "buzz" },
    { foo => "bar", -or => { 0 => \"= baz" }, bizz => "buzz" },

    { foo => "bar", 0 => \"= baz", bizz => "buzz" },
    { foo => "bar", 0 => \["= baz"], bizz => "buzz" },
  ) {
    push @tests, {
      func    => 'where',
      args    => [ $where_arg ],
      stmt    => 'WHERE 0 = baz AND bizz = ? AND foo = ?',
      stmt_q  => 'WHERE `0` = baz AND `bizz` = ? AND `foo` = ?',
      bind    => [qw( buzz bar )],
    };
  }

  for my $where_arg (
    [ -and => [ 0 => \"= baz" ], bizz => "buzz", foo => "bar" ],
    [ -or => [ 0 => \"= baz" ], bizz => "buzz", foo => "bar" ],
    [ 0 => \"= baz", bizz => "buzz", foo => "bar" ],
    [ 0 => \["= baz"], bizz => "buzz", foo => "bar" ],
  ) {
    push @tests, {
      func    => 'where',
      args    => [ $where_arg ],
      stmt    => 'WHERE 0 = baz OR bizz = ? OR foo = ?',
      stmt_q  => 'WHERE `0` = baz OR `bizz` = ? OR `foo` = ?',
      bind    => [qw( buzz bar )],
    };
  }
}

for my $t (@tests) {
  my $new = $t->{new} || {};

  for my $quoted (0, 1) {

    my $maker = SQL::Abstract->new(
      %$new,
      ($quoted ? (
        quote_char => '`',
        name_sep => '.',
        ( $t->{esc} ? (
          escape_char => $t->{esc},
        ) : ())
      ) : ())
    );

    my($stmt, @bind);

    my $cref = sub {
      my $op = $t->{func};
      ($stmt, @bind) = $maker->$op(@{ $t->{args} });
    };

    if (my $e = $t->{throws}) {
      throws_ok(
        sub { $cref->() },
        $e,
      ) || diag dumper({ args => $t->{args}, result => $stmt });
    }
    else {
      lives_ok(sub {
        alarm(1); local $SIG{ALRM} = sub {
          no warnings 'redefine';
          my $orig = Carp->can('caller_info');
          local *Carp::caller_info = sub { return if $_[0] > 20; &$orig };
          print STDERR "ARGH ($SQL::Abstract::Default_Scalar_To): ".Carp::longmess();
          die "timed out";
        };
        warnings_like(
          sub { $cref->() },
          $t->{warns} || [],
        ) || diag dumper({ args => $t->{args}, result => $stmt });
      }) || diag dumper({ args => $t->{args}, result => $stmt, threw => $@ });

      is_same_sql_bind(
        $stmt,
        \@bind,
        $quoted ? $t->{stmt_q}: $t->{stmt},
        $t->{bind}
      ) || diag dumper({ args => $t->{args}, result => $stmt });;
    }
  }
}

done_testing;
