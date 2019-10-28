use strict;
use warnings;
use Test::More;
use Test::Warn;
use Test::Exception;
use SQL::Abstract::Test import => [qw(is_same_sql_bind diag_where dumper) ];

use SQL::Abstract;

my $not_stringifiable = bless {}, 'SQLA::NotStringifiable';

my @handle_tests = (
    {
        where => 'foo',
        order => [],
        stmt => ' WHERE foo',
        bind => [],
    },
    {
        where => {
            requestor => 'inna',
            worker => ['nwiger', 'rcwe', 'sfz'],
            status => { '!=', 'completed' }
        },
        order => [],
        stmt => " WHERE ( requestor = ? AND status != ? AND ( ( worker = ? ) OR"
              . " ( worker = ? ) OR ( worker = ? ) ) )",
        bind => [qw/inna completed nwiger rcwe sfz/],
    },

    {
        where  => [
            status => 'completed',
            user   => 'nwiger',
        ],
        stmt => " WHERE ( status = ? OR user = ? )",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => 'completed'
        },
        order => [qw/ticket/],
        stmt => " WHERE ( status = ? AND user = ? ) ORDER BY ticket",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => { '!=', 'completed' }
        },
        order => [qw/ticket/],
        stmt => " WHERE ( status != ? AND user = ? ) ORDER BY ticket",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            status   => 'completed',
            reportid => { 'in', [567, 2335, 2] }
        },
        order => [],
        stmt => " WHERE ( reportid IN ( ?, ?, ? ) AND status = ? )",
        bind => [qw/567 2335 2 completed/],
    },

    {
        where  => {
            status   => 'completed',
            reportid => { 'not in', [567, 2335, 2] }
        },
        order => [],
        stmt => " WHERE ( reportid NOT IN ( ?, ?, ? ) AND status = ? )",
        bind => [qw/567 2335 2 completed/],
    },

    {
        where  => {
            status   => 'completed',
            completion_date => { 'between', ['2002-10-01', '2003-02-06'] },
        },
        order => \'ticket, requestor',
        stmt => "WHERE ( ( completion_date BETWEEN ? AND ? ) AND status = ? ) ORDER BY ticket, requestor",
        bind => [qw/2002-10-01 2003-02-06 completed/],
    },

    {
        where => [
            {
                user   => 'nwiger',
                status => { 'in', ['pending', 'dispatched'] },
            },
            {
                user   => 'robot',
                status => 'unassigned',
            },
        ],
        order => [],
        stmt => " WHERE ( ( status IN ( ?, ? ) AND user = ? ) OR ( status = ? AND user = ? ) )",
        bind => [qw/pending dispatched nwiger unassigned robot/],
    },

    {
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => \'is not null',
        },
        order => 'priority',
        stmt => " WHERE ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor is not null ) ORDER BY priority",
        bind => [qw/3 1/],
    },

    {
        where => {
            requestor => { '!=', ['-and', undef, ''] },
        },
        stmt => " WHERE ( requestor IS NOT NULL AND requestor != ? )",
        bind => [''],
    },

    {
        where => {
            requestor => [undef, ''],
        },
        stmt => " WHERE ( requestor IS NULL OR requestor = ? )",
        bind => [''],
    },

    {
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => { '!=', undef },
        },
        order => [qw/a b c d e f g/],
        stmt => " WHERE ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor IS NOT NULL )"
              . " ORDER BY a, b, c, d, e, f, g",
        bind => [qw/3 1/],
    },

    {
        where => {
            priority  => { 'between', [1, 3] },
            requestor => { 'like', undef },
        },
        order => \'requestor, ticket',
        stmt => " WHERE ( ( priority BETWEEN ? AND ? ) AND requestor IS NULL ) ORDER BY requestor, ticket",
        bind => [qw/1 3/],
        warns => qr/Supplying an undefined argument to 'LIKE' is deprecated/,
    },


    {
        where => {
          id  => 1,
          num => {
           '<=' => 20,
           '>'  => 10,
          },
        },
        stmt => " WHERE ( id = ? AND ( num <= ? AND num > ? ) )",
        bind => [qw/1 20 10/],
    },

    {
        where => { foo => {-not_like => [7,8,9]},
                   fum => {'like' => [qw/a b/]},
                   nix => {'between' => [100,200] },
                   nox => {'not between' => [150,160] },
                   wix => {'in' => [qw/zz yy/]},
                   wux => {'not_in'  => [qw/30 40/]}
                 },
        stmt => " WHERE ( ( ( foo NOT LIKE ? ) OR ( foo NOT LIKE ? ) OR ( foo NOT LIKE ? ) ) AND ( ( fum LIKE ? ) OR ( fum LIKE ? ) ) AND ( nix BETWEEN ? AND ? ) AND ( nox NOT BETWEEN ? AND ? ) AND wix IN ( ?, ? ) AND wux NOT IN ( ?, ? ) )",
        bind => [7,8,9,'a','b',100,200,150,160,'zz','yy','30','40'],
        warns => qr/\QA multi-element arrayref as an argument to the inequality op 'NOT LIKE' is technically equivalent to an always-true 1=1/,
    },

    {
        where => {
            bar => {'!=' => []},
        },
        stmt => " WHERE ( 1=1 )",
        bind => [],
    },

    {
        where => {
            id  => [],
        },
        stmt => " WHERE ( 0=1 )",
        bind => [],
    },


    {
        where => {
            foo => \["IN (?, ?)", 22, 33],
            bar => [-and =>  \["> ?", 44], \["< ?", 55] ],
        },
        stmt => " WHERE ( (bar > ? AND bar < ?) AND foo IN (?, ?) )",
        bind => [44, 55, 22, 33],
    },

    {
        where => {
          -and => [
            user => 'nwiger',
            [
              -and => [ workhrs => {'>', 20}, geo => 'ASIA' ],
              -or => { workhrs => {'<', 50}, geo => 'EURO' },
            ],
          ],
        },
        stmt => "WHERE ( user = ? AND (
               ( workhrs > ? AND geo = ? )
            OR ( geo = ? OR workhrs < ? )
          ) )",
        bind => [qw/nwiger 20 ASIA EURO 50/],
    },

   {
       where => { -and => [{}, { 'me.id' => '1'}] },
       stmt => " WHERE ( ( me.id = ? ) )",
       bind => [ 1 ],
   },

   {
       where => { foo => $not_stringifiable, },
       stmt => " WHERE ( foo = ? )",
       bind => [ $not_stringifiable ],
   },

   {
       where => \[ 'foo = ?','bar' ],
       stmt => " WHERE (foo = ?)",
       bind => [ "bar" ],
   },

   {
       where => [ \[ 'foo = ?','bar' ] ],
       stmt => " WHERE (foo = ?)",
       bind => [ "bar" ],
   },

   {
       where => { -bool => \'function(x)' },
       stmt => " WHERE function(x)",
       bind => [],
   },

   {
       where => { -bool => 'foo' },
       stmt => " WHERE foo",
       bind => [],
   },

   {
       where => { -and => [-bool => 'foo', -bool => 'bar'] },
       stmt => " WHERE foo AND bar",
       bind => [],
   },

   {
       where => { -or => [-bool => 'foo', -bool => 'bar'] },
       stmt => " WHERE foo OR bar",
       bind => [],
   },

   {
       where => { -not_bool => \'function(x)' },
       stmt => " WHERE NOT function(x)",
       bind => [],
   },

   {
       where => { -not_bool => 'foo' },
       stmt => " WHERE NOT foo",
       bind => [],
   },

   {
       where => { -and => [-not_bool => 'foo', -not_bool => 'bar'] },
       stmt => " WHERE (NOT foo) AND (NOT bar)",
       bind => [],
   },

   {
       where => { -or => [-not_bool => 'foo', -not_bool => 'bar'] },
       stmt => " WHERE (NOT foo) OR (NOT bar)",
       bind => [],
   },

   {
       where => { -bool => \['function(?)', 20]  },
       stmt => " WHERE function(?)",
       bind => [20],
   },

   {
       where => { -not_bool => \['function(?)', 20]  },
       stmt => " WHERE NOT function(?)",
       bind => [20],
   },

   {
       where => { -bool => { a => 1, b => 2}  },
       stmt => " WHERE a = ? AND b = ?",
       bind => [1, 2],
   },

   {
       where => { -bool => [ a => 1, b => 2] },
       stmt => " WHERE a = ? OR b = ?",
       bind => [1, 2],
   },

   {
       where => { -not_bool => { a => 1, b => 2}  },
       stmt => " WHERE NOT (a = ? AND b = ?)",
       bind => [1, 2],
   },

   {
       where => { -not_bool => [ a => 1, b => 2] },
       stmt => " WHERE NOT ( a = ? OR b = ? )",
       bind => [1, 2],
   },

# Op against internal function
   {
       where => { bool1 => { '=' => { -not_bool => 'bool2' } } },
       stmt => " WHERE ( bool1 = (NOT bool2) )",
       bind => [],
   },
   {
       where => { -not_bool => { -not_bool => { -not_bool => 'bool2' } } },
       stmt => " WHERE ( NOT ( NOT ( NOT bool2 ) ) )",
       bind => [],
   },

# Op against random functions (these two are oracle-specific)
   {
       where => { timestamp => { '!=' => { -trunc => { -year => \'sysdate' } } } },
       stmt => " WHERE ( timestamp != TRUNC(YEAR(sysdate)) )",
       bind => [],
   },
   {
       where => { timestamp => { '>=' => { -to_date => '2009-12-21 00:00:00' } } },
       stmt => " WHERE ( timestamp >= TO_DATE(?) )",
       bind => ['2009-12-21 00:00:00'],
   },

# Legacy function specs
   {
       where => { ip => {'<<=' => '127.0.0.1/32' } },
       stmt => "WHERE ( ip <<= ? )",
       bind => ['127.0.0.1/32'],
   },
   {
       where => { foo => { 'GLOB' => '*str*' } },
       stmt => " WHERE foo GLOB ? ",
       bind => [ '*str*' ],
   },
   {
       where => { foo => { 'REGEXP' => 'bar|baz' } },
       stmt => " WHERE foo REGEXP ? ",
       bind => [ 'bar|baz' ],
   },

# Tests for -not
# Basic tests only
    {
        where => { -not => { a => 1 } },
        stmt  => " WHERE ( (NOT a = ?) ) ",
        bind => [ 1 ],
    },
    {
        where => { a => 1, -not => { b => 2 } },
        stmt  => " WHERE ( ( (NOT b = ?) AND a = ? ) ) ",
        bind => [ 2, 1 ],
    },
    {
        where => { -not => { a => 1, b => 2, c => 3 } },
        stmt  => " WHERE ( (NOT ( a = ? AND b = ? AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
    {
        where => { -not => [ a => 1, b => 2, c => 3 ] },
        stmt  => " WHERE ( (NOT ( a = ? OR b = ? OR c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
    {
        where => { -not => { c => 3, -not => { b => 2, -not => { a => 1 } } } },
        stmt  => " WHERE ( (NOT ( (NOT ( (NOT a = ?) AND b = ? )) AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
    {
        where => { -not => { -bool => 'c', -not => { -not_bool => 'b', -not => { a => 1 } } } },
        stmt  => " WHERE ( (NOT ( c AND (NOT ( (NOT a = ?) AND (NOT b) )) )) ) ",
        bind => [ 1 ],
    },
    {
        where => \"0",
        stmt  => " WHERE ( 0 ) ",
        bind => [ ],
    },
    {
        where => { artistid => {} },
        stmt => '',
        bind => [ ],
    },
    {
        where => [ -and => [ {}, [] ], -or => [ {}, [] ] ],
        stmt => '',
        bind => [ ],
    },
    {
        where => { '=' => \'bozz' },
        stmt => 'WHERE = bozz',
        bind => [ ],
    },
);

for my $case (@handle_tests) {
    my $sql = SQL::Abstract->new;
    my ($stmt, @bind);
    lives_ok {
      warnings_like {
        ($stmt, @bind) = $sql->where($case->{where}, $case->{order});
      } $case->{warns} || [];
    };

    is_same_sql_bind($stmt, \@bind, $case->{stmt}, $case->{bind})
      || do { diag_where ( $case->{where} ); diag dumper($sql->_expand_expr($case->{where})) };
}

done_testing;
