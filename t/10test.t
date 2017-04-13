use strict;
use warnings;

use Test::More;

use SQL::Abstract::Test import => [qw(
  eq_sql_bind eq_sql eq_bind is_same_sql_bind dumper $sql_differ
)];

my @sql_tests = (
      # WHERE condition - equal
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1/,
          q/SELECT foo FROM bar WHERE a=1/,
          q/SELECT foo FROM bar WHERE (a = 1)/,
          q/SELECT foo FROM bar WHERE (a=1)/,
          q/SELECT foo FROM bar WHERE ( a = 1 )/,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              a = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              (a = 1)
          /,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              ( a = 1 )
          /,
          q/SELECT foo FROM bar WHERE ((a = 1))/,
          q/SELECT foo FROM bar WHERE ( (a = 1) )/,
          q/SELECT foo FROM bar WHERE ( ( a = 1 ) )/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1/,
          q/SELECT foo FROM bar WHERE (a = 1) AND (b = 1)/,
          q/SELECT foo FROM bar WHERE ((a = 1) AND (b = 1))/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1)/,
          q/SELECT foo FROM bar WHERE ((a = 1 AND b = 1))/,
          q/SELECT foo FROM bar WHERE (((a = 1) AND (b = 1)))/,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              a = 1
              AND
              b = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              (a = 1
              AND
              b = 1)
          /,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              (a = 1)
              AND
              (b = 1)
          /,
          q/
            SELECT
              foo
            FROM
              bar
            WHERE
              ((a = 1)
              AND
              (b = 1))
          /,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 AND c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1 AND c = 1)/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1) AND c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 1 AND c = 1)/,
          q/SELECT foo FROM bar WHERE ((((a = 1))) AND (b = 1 AND c = 1))/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 OR b = 1 OR c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 OR b = 1) OR c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 OR (b = 1 OR c = 1)/,
          q/SELECT foo FROM bar WHERE a = 1 OR ((b = 1 OR (c = 1)))/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE (a = 1) AND (b = 1 OR c = 1 OR d = 1) AND (e = 1 AND f = 1)/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 1 OR c = 1 OR d = 1) AND e = 1 AND (f = 1)/,
          q/SELECT foo FROM bar WHERE ( ((a = 1) AND ( b = 1 OR (c = 1 OR d = 1) )) AND ((e = 1)) AND f = 1) /,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE (a) AND (b = 2)/,
          q/SELECT foo FROM bar WHERE (a AND b = 2)/,
          q/SELECT foo FROM bar WHERE (a AND (b = 2))/,
          q/SELECT foo FROM bar WHERE a AND (b = 2)/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar WHERE ((NOT a) AND b = 2)/,
          q/SELECT foo FROM bar WHERE (NOT a) AND (b = 2)/,
          q/SELECT foo FROM bar WHERE (NOT (a)) AND b = 2/,
        ],
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE NOT a AND (b = 2)/,
          q/SELECT foo FROM bar WHERE (NOT a) AND (b = 2)/,
        ]
      },
      {
        equal => 0,
        opts => { parenthesis_significant => 1 },
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 AND c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1 AND c = 1)/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1) AND c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 1 AND c = 1)/,
          q/SELECT foo FROM bar WHERE ((((a = 1))) AND (b = 1 AND c = 1))/,
        ]
      },
      {
        equal => 0,
        opts => { parenthesis_significant => 1 },
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 OR b = 1 OR c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 OR b = 1) OR c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 OR (b = 1 OR c = 1)/,
          q/SELECT foo FROM bar WHERE a = 1 OR ((b = 1 OR (c = 1)))/,
        ]
      },
      {
        equal => 0,
        opts => { parenthesis_significant => 1 },
        statements => [
          q/SELECT foo FROM bar WHERE (a = 1) AND (b = 1 OR c = 1 OR d = 1) AND (e = 1 AND f = 1)/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 1 OR c = 1 OR d = 1) AND e = 1 AND (f = 1)/,
          q/SELECT foo FROM bar WHERE ( ((a = 1) AND ( b = 1 OR (c = 1 OR d = 1) )) AND ((e = 1)) AND f = 1) /,
        ]
      },

      # WHERE condition - different
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1/,
          q/SELECT quux FROM bar WHERE a = 1/,
          q/SELECT foo FROM quux WHERE a = 1/,
          q/FOOBAR foo FROM bar WHERE a = 1/,

          q/SELECT foo FROM bar WHERE a = 2/,
          q/SELECT foo FROM bar WHERE a < 1/,
          q/SELECT foo FROM bar WHERE b = 1/,
          q/SELECT foo FROM bar WHERE (c = 1)/,
          q/SELECT foo FROM bar WHERE (d = 1)/,

          q/SELECT foo FROM bar WHERE a = 1 AND quux/,
          q/SELECT foo FROM bar WHERE a = 1 GROUP BY foo/,
          q/SELECT foo FROM bar WHERE a = 1 ORDER BY foo/,
          q/SELECT foo FROM bar WHERE a = 1 LIMIT 1/,
          q/SELECT foo FROM bar WHERE a = 1 OFFSET 1/,
          q/SELECT foo FROM bar JOIN quux WHERE a = 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 WHERE a = 1/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1/,
          q/SELECT quux FROM bar WHERE a = 1 AND b = 1/,
          q/SELECT foo FROM quux WHERE a = 1 AND b = 1/,
          q/FOOBAR foo FROM bar WHERE a = 1 AND b = 1/,

          q/SELECT foo FROM bar WHERE a = 2 AND b = 1/,
          q/SELECT foo FROM bar WHERE a = 3 AND (b = 1)/,
          q/SELECT foo FROM bar WHERE (a = 4) AND b = 1/,
          q/SELECT foo FROM bar WHERE (a = 5) AND (b = 1)/,
          q/SELECT foo FROM bar WHERE ((a = 6) AND (b = 1))/,
          q/SELECT foo FROM bar WHERE ((a = 7) AND (b = 1))/,

          q/SELECT foo FROM bar WHERE a = 1 AND b = 2/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 3)/,
          q/SELECT foo FROM bar WHERE (a = 1) AND b = 4/,
          q/SELECT foo FROM bar WHERE (a = 1) AND (b = 5)/,
          q/SELECT foo FROM bar WHERE ((a = 1) AND (b = 6))/,
          q/SELECT foo FROM bar WHERE ((a = 1) AND (b = 7))/,

          q/SELECT foo FROM bar WHERE a < 1 AND b = 1/,
          q/SELECT foo FROM bar WHERE b = 1 AND b = 1/,
          q/SELECT foo FROM bar WHERE (c = 1) AND b = 1/,
          q/SELECT foo FROM bar WHERE (d = 1) AND b = 1/,

          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 AND quux/,
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 GROUP BY foo/,
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 ORDER BY foo/,
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 LIMIT 1/,
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 OFFSET 1/,
          q/SELECT foo FROM bar JOIN quux WHERE a = 1 AND b = 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 WHERE a = 1 AND b = 1/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 AND b = 1 OR c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 AND b = 1) OR c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 AND (b = 1 OR c = 1)/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE a = 1 OR b = 1 AND c = 1/,
          q/SELECT foo FROM bar WHERE (a = 1 OR b = 1) AND c = 1/,
          q/SELECT foo FROM bar WHERE a = 1 OR (b = 1 AND c = 1)/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar WHERE a IN (1,3,2)/,
          q/SELECT foo FROM bar WHERE a IN 1,2,3/,
          q/SELECT foo FROM bar WHERE a IN (1,2,3)/,
          q/SELECT foo FROM bar WHERE a IN ((1,2,3))/,
        ]
      },
      {
        equal => 0,
        statements => [
          # BETWEEN with/without parenthesis around itself/RHS is a sticky business
          # if I made a mistake here, simply rewrite the special BETWEEN handling in
          # _recurse_parse()
          #
          # by RIBASUSHI
          q/SELECT foo FROM bar WHERE ( completion_date BETWEEN ? AND ? AND status = ? )/,
          q/SELECT foo FROM bar WHERE completion_date BETWEEN (? AND ?) AND status = ?/,
          q/SELECT foo FROM bar WHERE ( (completion_date BETWEEN (? AND ?) ) AND status = ? )/,
          q/SELECT foo FROM bar WHERE ( (completion_date BETWEEN (? AND ? AND status = ?) ) )/,
        ]
      },

      # IS NULL (special LHS-only op)
      {
        equal => 1,
        statements => [
          q/WHERE a IS NOT NULL AND b IS NULL/,
          q/WHERE (a IS NOT NULL) AND b IS NULL/,
          q/WHERE a IS NOT NULL AND (b IS NULL)/,
          q/WHERE (a IS NOT NULL) AND ((b IS NULL))/,
        ],
      },

      # JOIN condition - equal
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar JOIN baz ON a = 1 WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON a=1 WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON (a = 1) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON (a=1) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON ( a = 1 ) WHERE x = 1/,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              a = 1
            WHERE
              x = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              (a = 1)
            WHERE
              x = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              ( a = 1 )
            WHERE
              x = 1
          /,
          q/SELECT foo FROM bar JOIN baz ON ((a = 1)) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON ( (a = 1) ) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON ( ( a = 1 ) ) WHERE x = 1/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT foo FROM bar JOIN baz ON a = 1 AND b = 1 WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON (a = 1) AND (b = 1) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON ((a = 1) AND (b = 1)) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON (a = 1 AND b = 1) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON ((a = 1 AND b = 1)) WHERE x = 1/,
          q/SELECT foo FROM bar JOIN baz ON (((a = 1) AND (b = 1))) WHERE x = 1/,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              a = 1
              AND
              b = 1
            WHERE
              x = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              (a = 1
              AND
              b = 1)
            WHERE
              x = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              (a = 1)
              AND
              (b = 1)
            WHERE
              x = 1
          /,
          q/
            SELECT
              foo
            FROM
              bar
            JOIN
              baz
            ON
              ((a = 1)
              AND
              (b = 1))
            WHERE
              x = 1
          /,
        ]
      },

      # JOIN condition - different
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar JOIN quux ON a = 1 WHERE quuux/,
          q/SELECT quux FROM bar JOIN quux ON a = 1 WHERE quuux/,
          q/SELECT foo FROM quux JOIN quux ON a = 1 WHERE quuux/,
          q/FOOBAR foo FROM bar JOIN quux ON a = 1 WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a = 2 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON a < 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (c = 1) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (d = 1) WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a = 1 AND quuux/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 GROUP BY foo/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 ORDER BY foo/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 LIMIT 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 OFFSET 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 JOIN quuux/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 JOIN quuux ON a = 1/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 WHERE quuux/,
          q/SELECT quux FROM bar JOIN quux ON a = 1 AND b = 1 WHERE quuux/,
          q/SELECT foo FROM quux JOIN quux ON a = 1 AND b = 1 WHERE quuux/,
          q/FOOBAR foo FROM bar JOIN quux ON a = 1 AND b = 1 WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a = 2 AND b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON a = 3 AND (b = 1) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (a = 4) AND b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (a = 5) AND (b = 1) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON ((a = 6) AND (b = 1)) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON ((a = 7) AND (b = 1)) WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 2 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND (b = 3) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (a = 1) AND b = 4 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (a = 1) AND (b = 5) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON ((a = 1) AND (b = 6)) WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON ((a = 1) AND (b = 7)) WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a < 1 AND b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON b = 1 AND b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (c = 1) AND b = 1 WHERE quuux/,
          q/SELECT foo FROM bar JOIN quux ON (d = 1) AND b = 1 WHERE quuux/,

          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 AND quuux/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 GROUP BY foo/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 ORDER BY foo/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 LIMIT 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 AND b = 1 OFFSET 1/,
          q/SELECT foo FROM bar JOIN quux JOIN quuux ON a = 1 AND b = 1/,
          q/SELECT foo FROM bar JOIN quux ON a = 1 JOIN quuux ON a = 1 AND b = 1/,
        ]
      },

      # DISTINCT ON (...) not confused with JOIN ON (...)
      {
        equal => 1,
        statements => [
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE a = 1/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE a=1/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE (a = 1)/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE (a=1)/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE ( a = 1 )/,
          q/
            SELECT DISTINCT ON (foo, quux)
              foo,
              quux
            FROM
              bar
            WHERE
              a = 1
          /,
          q/
            SELECT DISTINCT ON (foo, quux)
              foo,
              quux
            FROM
              bar
            WHERE
              (a = 1)
          /,
          q/
            SELECT DISTINCT ON (foo, quux)
              foo,
              quux
            FROM
              bar
            WHERE
              ( a = 1 )
          /,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE ((a = 1))/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE ( (a = 1) )/,
          q/SELECT DISTINCT ON (foo, quux) foo, quux FROM bar WHERE ( ( a = 1 ) )/,
        ]
      },

      # subselects - equal
      {
        equal => 1,
        statements => [
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1)) AS foo WHERE (a = 1)/,
        ]
      },
      {
        equal => 1,
        statements => [
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 1) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 1)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 1) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 1)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 1))) AS foo WHERE a = 1/,

          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 1) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 1)) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 1) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 1)) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 1))) AS foo WHERE (a = 1)/,
        ]
      },

      # subselects - different
      {
        equal => 0,
        statements => [
          q/DELETE FROM cd WHERE ( cdid IN ( SELECT me.cdid FROM (SELECT * FROM cd me WHERE ( year != ? ) GROUP BY me.cdid) me WHERE ( year != ? ) ) )/,
          q/DELETE FROM cd WHERE ( cdid IN ( SELECT me.cdid FROM cd me WHERE ( year != ? ) GROUP BY me.cdid ) )/,
        ],
      },
      {
        equal => 0,
        statements => [
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1) AS foo WHERE a = 2/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1) AS foo WHERE (a = 3)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1)) AS foo WHERE a = 4/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1)) AS foo WHERE (a = 5)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 2) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 3) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 4)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 5)) AS foo WHERE (a = 1)/,
        ]
      },
      {
        equal => 0,
        statements => [
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 1) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 2) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 3)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 4)) AS foo WHERE a = 1/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 5))) AS foo WHERE a = 1/,

          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 6) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 7) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 8)) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 9)) AS foo WHERE (a = 1)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 10))) AS foo WHERE (a = 1)/,

          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 1) AS foo WHERE a = 2/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 2) AS foo WHERE a = 2/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 3)) AS foo WHERE a = 2/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 4)) AS foo WHERE a = 2/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 5))) AS foo WHERE a = 2/,

          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND c = 6) AS foo WHERE (a = 2)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND c = 7) AS foo WHERE (a = 2)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE b = 1 AND (c = 8)) AS foo WHERE (a = 2)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE (b = 1) AND (c = 9)) AS foo WHERE (a = 2)/,
          q/SELECT * FROM (SELECT * FROM bar WHERE ((b = 1) AND (c = 10))) AS foo WHERE (a = 2)/,
        ]
      },

      # order by
      {
        equal => 1,
        statements => [
          q/SELECT * FROM foo ORDER BY bar/,
          q/SELECT * FROM foo ORDER BY bar ASC/,
          q/SELECT * FROM foo ORDER BY bar asc/,
        ],
      },
      {
        equal => 1,
        statements => [
          q/SELECT * FROM foo ORDER BY bar, baz ASC/,
          q/SELECT * FROM foo ORDER BY bar ASC, baz/,
          q/SELECT * FROM foo ORDER BY bar asc, baz ASC/,
          q/SELECT * FROM foo ORDER BY bar, baz/,
        ],
      },
      {
        equal => 1,
        statements => [
          q/ORDER BY colA, colB LIKE ? DESC, colC LIKE ?/,
          q/ORDER BY colA ASC, colB LIKE ? DESC, colC LIKE ? ASC/,
        ],
      },
      {
        equal => 1,
        statements => [
          q/ORDER BY name + ?, [me].[id]/,
          q/ORDER BY name + ? ASC, [me].[id]/,
        ],
      },
      {
        equal => 0,
        opts => { order_by_asc_significant => 1 },
        statements => [
          q/SELECT * FROM foo ORDER BY bar/,
          q/SELECT * FROM foo ORDER BY bar ASC/,
          q/SELECT * FROM foo ORDER BY bar desc/,
        ],
      },

      # list permutations
      {
        equal => 0,
        statements => [
          'SELECT a,b,c FROM foo',
          'SELECT a,c,b FROM foo',
          'SELECT b,a,c FROM foo',
          'SELECT b,c,a FROM foo',
          'SELECT c,a,b FROM foo',
          'SELECT c,b,a FROM foo',
        ],
      },
      {
        equal => 0,
        statements => [
          'SELECT * FROM foo WHERE a IN (1,2,3)',
          'SELECT * FROM foo WHERE a IN (1,3,2)',
          'SELECT * FROM foo WHERE a IN (2,1,3)',
          'SELECT * FROM foo WHERE a IN (2,3,1)',
          'SELECT * FROM foo WHERE a IN (3,1,2)',
          'SELECT * FROM foo WHERE a IN (3,2,1)',
        ]
      },

      # list consistency
      {
        equal => 0,
        statements => [
          'SELECT a,b FROM foo',
          'SELECT a,,b FROM foo',
          'SELECT a,b, FROM foo',
          'SELECT ,a,b, FROM foo',
          'SELECT ,a,,b, FROM foo',
        ],
      },

      # misc func
      {
        equal => 0,
        statements => [
          'SELECT count(*) FROM foo',
          'SELECT count(*) AS bar FROM foo',
          'SELECT count(*) AS "bar" FROM foo',
          'SELECT count(a) FROM foo',
          'SELECT count(1) FROM foo',
        ]
      },
      {
        equal => 1,
        statements => [
          'SELECT foo() bar FROM baz',
          'SELECT foo (  )bar FROM baz',
          'SELECT foo (())bar FROM baz',
          'SELECT foo(( ) ) bar FROM baz',
        ]
      },
      {
        equal => 0,
        statements => [
          'SELECT foo() FROM bar',
          'SELECT foo FROM bar',
          'SELECT foo FROM bar ()',
        ]
      },
      {
        equal => 0,
        statements => [
          'SELECT COUNT * FROM foo',
          'SELECT COUNT( * ) FROM foo',
        ]
      },
      # single ? of unknown funcs do not unroll unless
      # explicitly allowed (e.g. Like)
      {
        equal => 0,
        statements => [
          'SELECT foo FROM bar WHERE bar > foo ?',
          'SELECT foo FROM bar WHERE bar > foo( ? )',
        ]
      },
      {
        equal => 1,
        statements => [
          'SELECT foo FROM bar WHERE bar LIKE ?',
          'SELECT foo FROM bar WHERE bar LiKe (?)',
          'SELECT foo FROM bar WHERE bar lIkE( (?))',
        ]
      },
      # test multival
      {
        equal => 0,
        statements => [
          'SELECT foo FROM bar WHERE foo IN (?, ?)',
          'SELECT foo FROM bar WHERE foo IN ?, ?',
        ]
      },
      # math
      {
        equal => 0,
        statements => [
          'SELECT * FROM foo WHERE 1 = ( a > b)',
          'SELECT * FROM foo WHERE 1 = a > b',
          'SELECT * FROM foo WHERE (1 = a) > b',
        ]
      },
      {
        equal => 1,
        statements => [
          'SELECT * FROM foo WHERE bar = baz(buzz)',
          'SELECT * FROM foo WHERE bar = (baz( buzz ))',
        ]
      },
      # oddballs
      {
        equal => 1,
        statements => [
          'WHERE ( foo GLOB ? )',
          'WHERE foo GLOB ?',
        ],
      },
      {
        equal => 1,
        statements => [
          'SELECT FIRST ? SKIP ? [me].[id], [me].[owner]
            FROM [books] [me]
          WHERE ( ( (EXISTS (
            SELECT FIRST ? SKIP ? [owner].[id]
              FROM [owners] [owner]
            WHERE ( [books].[owner] = [owner].[id] )
          )) AND [source] = ? ) )',
          'SELECT FIRST ? SKIP ? [me].[id], [me].[owner]
            FROM [books] [me]
          WHERE ( ( EXISTS (
            SELECT FIRST ? SKIP ? [owner].[id]
              FROM [owners] [owner]
            WHERE ( [books].[owner] = [owner].[id] )
          ) AND [source] = ? ) )',
        ],
      },
      {
        equal => 1,
        statements => [
          'WHERE foo = ? FETCH FIRST 1 ROWS ONLY',
          'WHERE ( foo = ? ) FETCH FIRST 1 ROWS ONLY',
          'WHERE (( foo = ? )) FETCH FIRST 1 ROWS ONLY',
        ],
      },
);

my @bind_tests = (
  # scalar - equal
  {
    equal => 1,
    bindvals => [
      undef,
      undef,
    ]
  },
  {
    equal => 1,
    bindvals => [
      'foo',
      'foo',
    ]
  },
  {
    equal => 1,
    bindvals => [
      42,
      42,
      '42',
    ]
  },

  # scalarref - equal
  {
    equal => 1,
    bindvals => [
      \'foo',
      \'foo',
    ]
  },
  {
    equal => 1,
    bindvals => [
      \42,
      \42,
      \'42',
    ]
  },

  # arrayref - equal
  {
    equal => 1,
    bindvals => [
      [],
      []
    ]
  },
  {
    equal => 1,
    bindvals => [
      [42],
      [42],
      ['42'],
    ]
  },
  {
    equal => 1,
    bindvals => [
      [1, 42],
      [1, 42],
      ['1', 42],
      [1, '42'],
      ['1', '42'],
    ]
  },

  # hashref - equal
  {
    equal => 1,
    bindvals => [
      { foo => 42 },
      { foo => 42 },
      { foo => '42' },
    ]
  },
  {
    equal => 1,
    bindvals => [
      { foo => 42, bar => 1 },
      { foo => 42, bar => 1 },
      { foo => '42', bar => 1 },
    ]
  },

  # blessed object - equal
  {
    equal => 1,
    bindvals => [
      bless(\(local $_ = 42), 'Life::Universe::Everything'),
      bless(\(local $_ = 42), 'Life::Universe::Everything'),
    ]
  },
  {
    equal => 1,
    bindvals => [
      bless([42], 'Life::Universe::Everything'),
      bless([42], 'Life::Universe::Everything'),
    ]
  },
  {
    equal => 1,
    bindvals => [
      bless({ answer => 42 }, 'Life::Universe::Everything'),
      bless({ answer => 42 }, 'Life::Universe::Everything'),
    ]
  },

  # complex data structure - equal
  {
    equal => 1,
    bindvals => [
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
    ]
  },


  # scalar - different
  {
    equal => 0,
    bindvals => [
      undef,
      'foo',
      42,
    ]
  },

  # scalarref - different
  {
    equal => 0,
    bindvals => [
      \undef,
      \'foo',
      \42,
    ]
  },

  # arrayref - different
  {
    equal => 0,
    bindvals => [
      [undef],
      ['foo'],
      [42],
    ]
  },

  # hashref - different
  {
    equal => 0,
    bindvals => [
      { foo => undef },
      { foo => 'bar' },
      { foo => 42 },
    ]
  },

  # different types
  {
    equal => 0,
    bindvals => [
      'foo',
      \'foo',
      ['foo'],
      { foo => 'bar' },
    ]
  },

  # complex data structure - different
  {
    equal => 0,
    bindvals => [
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [43, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'baz', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { bar => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quuux => [1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [0, 1, 2, \3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, 3, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \4, { quux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quuux => [4, 5] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5, 6] } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => 4 } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5], quuux => 1 } ] }, 8 ],
      [42, { foo => 'bar', quux => [1, 2, \3, { quux => [4, 5] } ] }, 8, 9 ],
    ]
  },
);

for my $test (@sql_tests) {

  # this does not work on 5.8.8 and earlier :(
  #local @{*SQL::Abstract::Test::}{keys %{$test->{opts}}} = map { \$_ } values %{$test->{opts}}
  #  if $test->{opts};

  my %restore_globals;

  for (keys %{$test->{opts} || {} }) {
    $restore_globals{$_} = ${${*SQL::Abstract::Test::}{$_}};
    ${*SQL::Abstract::Test::}{$_} = \ do { my $cp = $test->{opts}{$_} };
  }

  my $statements = $test->{statements};
  while (@$statements) {
    my $sql1 = shift @$statements;
    foreach my $sql2 (@$statements) {

      my $equal = eq_sql($sql1, $sql2);

      TODO: {
        local $TODO = $test->{todo} if $test->{todo};

        if ($test->{equal}) {
          ok($equal, "equal SQL expressions should have been considered equal");
        } else {
          ok(!$equal, "different SQL expressions should have been considered not equal");
        }

        if ($equal ^ $test->{equal}) {
          my ($ast1, $ast2) = map { SQL::Abstract::Test::parse ($_) } ($sql1, $sql2);
          $_ = dumper($_) for ($ast1, $ast2);

          diag "sql1: $sql1";
          diag "sql2: $sql2";
          note $sql_differ || 'No differences found';
          note "ast1: $ast1";
          note "ast2: $ast2";
        }
      }
    }
  }

  ${*SQL::Abstract::Test::}{$_} = \$restore_globals{$_}
    for keys %restore_globals;
}

for my $test (@bind_tests) {
  my $bindvals = $test->{bindvals};
  while (@$bindvals) {
    my $bind1 = shift @$bindvals;
    foreach my $bind2 (@$bindvals) {
      my $equal = eq_bind($bind1, $bind2);
      if ($test->{equal}) {
        ok($equal, "equal bind values considered equal");
      } else {
        ok(!$equal, "different bind values considered not equal");
      }

      if ($equal ^ $test->{equal}) {
        diag("bind1: " . dumper($bind1));
        diag("bind2: " . dumper($bind2));
      }
    }
  }
}

ok(eq_sql_bind(
    "SELECT * FROM foo WHERE id = ?", [42],
    "SELECT * FROM foo WHERE (id = ?)", [42],
  ),
  "eq_sql_bind considers equal SQL expressions and bind values equal"
);


ok(!eq_sql_bind(
    "SELECT * FROM foo WHERE id = ?", [42],
    "SELECT * FROM foo WHERE (id = ?)", [0],
  ),
  "eq_sql_bind considers equal SQL expressions and different bind values different"
);

ok(!eq_sql_bind(
    "SELECT * FROM foo WHERE id = ?", [42],
    "SELECT * FROM bar WHERE (id = ?)", [42],
  ),
  "eq_sql_bind considers different SQL expressions and equal bind values different"
);

# test diag string
ok (! eq_sql (
  'SELECT owner_name FROM books me WHERE ( source = ? )',
  'SELECT owner_name FROM books me WHERE ( sUOrce = ? )',
));
like(
  $sql_differ,
  qr/\Q[ source ] != [ sUOrce ]/,
  'expected debug of literal diff',
);

ok (! eq_sql (
  'SELECT owner_name FROM books me ORDER BY owner_name',
  'SELECT owner_name FROM books me GROUP BY owner_name',
));
like(
  $sql_differ,
  qr/\QOP [ORDER BY] != [GROUP BY]/,
  'expected debug of op diff',
);

ok (! eq_sql (
  'SELECT owner_name FROM books WHERE ( source = ? )',
  'SELECT owner_name FROM books'
));

like(
  $sql_differ,
  qr|\Q[WHERE source = ?] != [N/A]|,
  'expected debug of missing branch',
);


ok (eq_sql_bind (
  \[ 'SELECT foo FROM bar WHERE baz = ? or buzz = ?', [ {} => 1 ], 2 ],
  'SELECT foo FROM bar WHERE (baz = ?) OR buzz = ?',
  [ [ {} => 1 ], 2 ],
), 'arrayrefref unpacks correctly' );

is_same_sql_bind(
  \[ 'SELECT foo FROM bar WHERE baz = ? or buzz = ?', [ {} => 1 ], 2 ],
  \[ 'SELECT foo FROM bar WHERE (( baz = ? OR (buzz = ?) ))', [ {} => 1 ], 2 ],
  'double arrayrefref unpacks correctly'
);

done_testing;
