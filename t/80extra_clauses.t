use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [ qw(is_same_sql_bind is_same_sql) ];
use SQL::Abstract;

my $sqlac = SQL::Abstract->new->plugin('+ExtraClauses');

is_deeply(
  [ $sqlac->statement_list ],
  [ sort qw(select update insert delete) ],
);

my ($sql, @bind) = $sqlac->select({
  select => [ qw(artist.id artist.name), { -json_agg => 'cd' } ],
  from => [
    { artists => { -as => 'artist' } },
    -join => [ cds => as => 'cd' => on => { 'cd.artist_id' => 'artist.id' } ],
  ],
  where => { 'artist.genres', => { '@>', { -value => [ 'Rock' ] } } },
  order_by => 'artist.name',
  group_by => 'artist.id',
  having => { '>' => [ { -count => 'cd.id' }, 3 ] }
});

is_same_sql_bind(
  $sql, \@bind,
  q{
    SELECT artist.id, artist.name, JSON_AGG(cd)
    FROM artists AS artist JOIN cds AS cd ON cd.artist_id = artist.id
    WHERE artist.genres @> ?
    GROUP BY artist.id
    HAVING COUNT(cd.id) > ?
    ORDER BY artist.name
  },
  [ [ 'Rock' ], 3 ]
);

($sql) = $sqlac->select({
  select => [ 'a' ],
  from => [ { -values => [ [ 1, 2 ], [ 3, 4 ] ] }, -as => [ qw(t a b) ] ],
});

is_same_sql($sql, q{SELECT a FROM (VALUES (1, 2), (3, 4)) AS t(a,b)});

($sql) = $sqlac->update({
  update => 'employees',
  set => { sales_count => { sales_count => { '+', \1 } } },
  from => 'accounts',
  where => {
    'accounts.name' => { '=' => \"'Acme Corporation'" },
    'employees.id' => { -ident => 'accounts.sales_person' },
  }
});

is_same_sql(
  $sql,
  q{UPDATE employees SET sales_count = sales_count + 1 FROM accounts
    WHERE accounts.name = 'Acme Corporation'
    AND employees.id = accounts.sales_person
  }
);

($sql) = $sqlac->update({
  update => [ qw(tab1 tab2) ],
  set => {
    'tab1.column1' => { -ident => 'value1' },
    'tab1.column2' => { -ident => 'value2' },
  },
  where => { 'tab1.id' => { -ident => 'tab2.id' } },
});

is_same_sql(
  $sql,
  q{UPDATE tab1, tab2 SET tab1.column1 = value1, tab1.column2 = value2
     WHERE tab1.id = tab2.id}
);

is_same_sql(
  $sqlac->delete({
    from => 'x',
    using => 'y',
    where => { 'x.id' => { -ident => 'y.x_id' } }
  }),
  q{DELETE FROM x USING y WHERE x.id = y.x_id}
);

is_same_sql(
  $sqlac->select({
    select => [ 'x.*', 'y.*' ],
    from => [ 'x', -join => [ 'y', using => 'y_id' ] ],
  }),
  q{SELECT x.*, y.* FROM x JOIN y USING (y_id)},
);

is_same_sql(
  $sqlac->select({
    select => 'x.*',
    from => [ { -select => { select => '*', from => 'y' } }, -as => 'x' ],
  }),
  q{SELECT x.* FROM (SELECT * FROM y) AS x},
);

is_same_sql(
  $sqlac->insert({
    into => 'foo',
    select => { select => '*', from => 'bar' }
  }),
  q{INSERT INTO foo SELECT * FROM bar}
);

($sql, @bind) = $sqlac->insert({
  into => 'eh',
  rowvalues => [ [ 1, 2 ], [ 3, 4 ], [ 5, 6 ] ]
});

is_same_sql_bind(
  $sql, \@bind,
  q{INSERT INTO eh VALUES (?, ?), (?, ?), (?, ?)},
  [ 1..6 ],
);

is_same_sql(
  $sqlac->select({
    select => '*',
    from => 'foo',
    where => { -not_exists => {
      -select => {
        select => \1,
        from => 'bar',
        where => { 'foo.id' => { -ident => 'bar.foo_id' } }
      },
    } },
  }),
  q{SELECT * FROM foo
    WHERE NOT EXISTS (SELECT 1 FROM bar WHERE foo.id = bar.foo_id)},
);

is_same_sql(
  $sqlac->select({
    select => '*',
    from => 'foo',
    where => { id => {
      '=' => { -select => { select => { -max => 'id' }, from => 'foo' } }
    } },
  }),
  q{SELECT * FROM foo WHERE id = (SELECT MAX(id) FROM foo)},
);

{
  my $sqlac = $sqlac->clone
                    ->clauses_of(
                        select => (
                          $sqlac->clauses_of('select'),
                          qw(limit offset),
                        )
                      );

  ($sql, @bind) = $sqlac->select({
    select => '*',
    from => 'foo',
    limit => 10,
    offset => 20,
  });

  is_same_sql_bind(
    $sql, \@bind,
    q{SELECT * FROM foo LIMIT ? OFFSET ?}, [ 10, 20 ]
  );
}

$sql = $sqlac->select({
  select => { -as => [ \1, 'x' ] },
  union => { -select => { select => { -as => [ \2, 'x' ] } } },
  order_by => { -desc => 'x' },
});

is_same_sql(
  $sql,
  q{(SELECT 1 AS x) UNION (SELECT 2 AS x) ORDER BY x DESC},
);

$sql = $sqlac->select({
  select => '*',
  from => 'foo',
  except => { -select => { select => '*', from => 'foo_exclusions' } }
});

is_same_sql(
  $sql,
  q{(SELECT * FROM foo) EXCEPT (SELECT * FROM foo_exclusions)},
);

$sql = $sqlac->select({
  with => [ foo => { -select => { select => \1 } } ],
  select => '*',
  from => 'foo'
});

is_same_sql(
  $sql,
  q{WITH foo AS (SELECT 1) SELECT * FROM foo},
);

$sql = $sqlac->update({
  _ => [ 'tree_table', -join => {
      to => { -select => {
        with_recursive => [
          [ tree_with_path => qw(id parent_id path) ],
          { -select => {
              _ => [
                qw(id parent_id),
                { -as => [
                  { -cast => { -as => [ id => char => 255 ] } },
                  'path'
                ] },
              ],
              from => 'tree_table',
              where => { parent_id => undef },
              union_all => {
                -select => {
                  _ => [ qw(t.id t.parent_id),
                         { -as => [
                             { -concat => [ 'r.path', \q{'/'}, 't.id' ] },
                             'path',
                         ] },
                       ],
                  from => [
                    tree_table => -as => t =>
                    -join => {
                      to => 'tree_with_path',
                      as => 'r',
                      on => { 't.parent_id' => 'r.id' },
                    },
                  ],
               } },
          } },
        ],
        select => '*',
        from => 'tree_with_path'
      } },
      as => 'tree',
      on => { 'tree.id' => 'tree_with_path.id' },
  } ],
  set => { path => { -ident => [ qw(tree path) ] } },
});

is_same_sql(
  $sql,
  q{
    UPDATE tree_table JOIN (
      WITH RECURSIVE tree_with_path(id, parent_id, path) AS (
        (
          SELECT id, parent_id, CAST(id AS char(255)) AS path
          FROM tree_table
          WHERE parent_id IS NULL
        )
        UNION ALL
        (
           SELECT t.id, t.parent_id, CONCAT(r.path, '/', t.id) AS path
           FROM tree_table AS t
           JOIN tree_with_path AS r ON t.parent_id = r.id
        )
      )
      SELECT * FROM tree_with_path
    ) AS tree
    ON tree.id = tree_with_path.id
    SET path = tree.path
  },
);


($sql, @bind) = $sqlac->insert({
  with => [
    faculty => {
      -select => {
        _ => [qw /p.person p.email/],
        from => [ person => -as => 'p' ],
        where => {
          'p.person_type' => 'faculty',
          'p.person_status' => { '!=' => 'pending' },
          'p.default_license_id' => undef,
        },
      },
    },
    grandfather => {
      -insert => {
        into => 'license',
        fields => [ qw(kind expires_on valid_from) ],
        select => {
          select => [\(qw('grandfather' '2017-06-30' '2016-07-01'))],
          from => 'faculty',
        },
        returning => 'license_id',
      }
    },
  ],
  into => 'license_person',
  fields => [ qw(person_id license_id) ],
  select => {
    _ => ['person_id', 'license_id'],
    from => ['grandfather'],
    where => {
      'a.index' => { -ident => 'b.index' },
    },
  },
});

is_same_sql_bind(
  $sql, \@bind,
  q{
    WITH faculty AS (
      SELECT p.person, p.email FROM person AS p
      WHERE (
        p.default_license_id IS NULL
        AND p.person_status != ?
        AND p.person_type = ?
      )
    ), grandfather AS (
      INSERT INTO license (kind, expires_on, valid_from)
      SELECT 'grandfather', '2017-06-30', '2016-07-01'
        FROM faculty RETURNING license_id
    ) INSERT INTO license_person (person_id, license_id)
      SELECT person_id, license_id FROM grandfather WHERE a.index = b.index
  },
  [ qw(pending faculty) ],
);


($sql, @bind) = $sqlac->delete({
  with => [
    instructors => {
      -select => {
        _ => [qw/p.person_id email default_license_id/],
        from => [
          person => -as => 'p',
          -join => {
            to => 'license_person',
            as => 'lp',
            on => { 'lp.person_id' => 'p.person_id' },
          },
          -join => {
            to => 'license',
            as => 'l',
            on => { 'l.license_id' => 'lp.license_id' },
          },
        ],
        where => {
          'p.person_type' => 'faculty',
          'p.person_status' => { '!=' => 'pending' },
          'l.kind' => 'pending',
        },
        group_by => [qw/ p.person_id /],
        having => { '>' => [ { -count => 'l.license_id' }, 1 ] }
      },
    },
    deletable_licenses => {
      -select => {
        _ => [qw/lp.ctid lp.person_id lp.license_id/],
        from => [
          instructors => -as => 'i',
          -join => {
            to => 'license_person',
            as => 'lp',
            on => { 'lp.person_id' => 'i.person_id' },
          },
          -join => {
            to => 'license',
            as => 'l',
            on => { 'l.license_id' => 'lp.license_id' },
          },
        ],
        where => {
          'lp.license_id' => {
            '<>' => {-ident => 'i.default_license_id'}
          },
          'l.kind' => 'pending',
        },
      },
    },
  ],
  from => 'license_person',
  where => {
    ctid => { -in =>
      {
        -select => {
          _ => ['ctid'],
          from => 'deletable_licenses',
        }
      }
    }
  }
});

is_same_sql_bind(
  $sql, \@bind,
  q{
    with instructors as (
      select p.person_id, email, default_license_id
      from person as p
      join license_person as lp on lp.person_id = p.person_id
      join license as l on l.license_id = lp.license_id
      where l.kind = ?
      AND p.person_status != ?
      AND p.person_type = ?
      group by p.person_id
      having COUNT(l.license_id) > ?),
    deletable_licenses as (
      select lp.ctid, lp.person_id, lp.license_id
      from instructors as i
      join license_person as lp on lp.person_id = i.person_id
      join license as l on l.license_id = lp.license_id
      where l.kind = ?
      and lp.license_id <> i.default_license_id
    )
    delete from license_person
    where ctid IN (
      (select ctid from deletable_licenses)
    )
  },
  [qw(
    pending pending faculty 1 pending
    )]
);

($sql, @bind) = $sqlac->update({
  _ => ['survey'],
  set => {
    license_id => { -ident => 'info.default_license_id' },
  },
  from => [
    -select => {
      select => [qw( s.survey_id p.default_license_id p.person_id)],
      from => [
        person => -as => 'p',
        -join => {
          to => 'class',
          as => 'c',
          on => { 'c.faculty_id' => 'p.person_id' },
        },
        -join => {
          to => 'survey',
          as => 's',
          on => { 's.class_id' => 'c.class_id' },
        },
      ],
      where => { 'p.institution_id' => { -value => 15031 } },
    },
    -as => 'info',
  ],
  where => {
    'info.survey_id' => { -ident => 'survey.survey_id' },
  }
});

is_same_sql_bind(
  $sql, \@bind,
  q{
    update survey
    set license_id=info.default_license_id
    from (
      select s.survey_id, p.default_license_id, p.person_id
      from person AS p
      join class AS c on c.faculty_id = p.person_id
      join survey AS s on s.class_id = c.class_id
      where p.institution_id = ?
    ) AS info
    where info.survey_id=survey.survey_id
  },
  [qw(
    15031
    )]
);

done_testing;
