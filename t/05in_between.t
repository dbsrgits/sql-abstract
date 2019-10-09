use strict;
use warnings;
use Test::More;
use Test::Warn;
use Test::Exception;
use SQL::Abstract::Test import => [qw(is_same_sql_bind diag_where dumper)];

use SQL::Abstract;

my @in_between_tests = (
  {
    where => { x => { -between => [1, 2] } },
    stmt => 'WHERE (x BETWEEN ? AND ?)',
    bind => [qw/1 2/],
    test => '-between with two placeholders',
  },
  {
    where => { x => { -between => [\"1", 2] } },
    stmt => 'WHERE (x BETWEEN 1 AND ?)',
    bind => [qw/2/],
    test => '-between with one literal sql arg and one placeholder',
  },
  {
    where => { x => { -between => [1, \"2"] } },
    stmt => 'WHERE (x BETWEEN ? AND 2)',
    bind => [qw/1/],
    test => '-between with one placeholder and one literal sql arg',
  },
  {
    where => { x => { -between => [\'current_date - 1', \'current_date - 0'] } },
    stmt => 'WHERE (x BETWEEN current_date - 1 AND current_date - 0)',
    bind => [],
    test => '-between with two literal sql arguments',
  },
  {
    where => { x => { -between => [ \['current_date - ?', 1], \['current_date - ?', 0] ] } },
    stmt => 'WHERE (x BETWEEN current_date - ? AND current_date - ?)',
    bind => [1, 0],
    test => '-between with two literal sql arguments with bind',
  },
  {
    where => { x => { -between => \['? AND ?', 1, 2] } },
    stmt => 'WHERE (x BETWEEN ? AND ?)',
    bind => [1,2],
    test => '-between with literal sql with placeholders (\["? AND ?", scalar, scalar])',
  },
  {
    where => { x => { -between => \["'something' AND ?", 2] } },
    stmt => "WHERE (x BETWEEN 'something' AND ?)",
    bind => [2],
    test => '-between with literal sql with one literal arg and one placeholder (\["\'something\' AND ?", scalar])',
  },
  {
    where => { x => { -between => \["? AND 'something'", 1] } },
    stmt => "WHERE (x BETWEEN ? AND 'something')",
    bind => [1],
    test => '-between with literal sql with one placeholder and one literal arg (\["? AND \'something\'", scalar])',
  },
  {
    where => { x => { -between => \"'this' AND 'that'" } },
    stmt => "WHERE (x BETWEEN 'this' AND 'that')",
    bind => [],
    test => '-between with literal sql with a literal (\"\'this\' AND \'that\'")',
  },

  # generate a set of invalid -between tests
  ( map { {
    where => { x => { -between => $_ } },
    test => 'invalid -between args',
    throws => qr|Operator 'BETWEEN' requires either an arrayref with two defined values or expressions, or a single literal scalarref/arrayref-ref|,
  } } (
    [ 1, 2, 3 ],
    [ 1, undef, 3 ],
    [ undef, 2, 3 ],
    [ 1, 2, undef ],
    [ 1, undef ],
    [ undef, 2 ],
    [ undef, undef ],
    [ 1 ],
    [ undef ],
    [],
    1,
    undef,
  )),
  {
    where => {
      start0 => { -between => [ 1, { -upper => 2 } ] },
      start1 => { -between => \["? AND ?", 1, 2] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", 'stuff' ],
      ] },
    },
    stmt => "WHERE (
          ( start0 BETWEEN ? AND UPPER(?)         )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )",
    bind => [1, 2, 1, 2, 'stuff'],
    test => '-between POD test',
  },
  {
    args => { restore_old_unop_handling => 1 },
    where => {
      start0 => { -between => [ 1, { -upper => 2 } ] },
      start1 => { -between => \["? AND ?", 1, 2] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", 'stuff' ],
      ] },
    },
    stmt => "WHERE (
          ( start0 BETWEEN ? AND UPPER ?          )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )",
    bind => [1, 2, 1, 2, 'stuff'],
    test => '-between POD test',
  },
  {
    args => { bindtype => 'columns' },
    where => {
      start0 => { -between => [ 1, { -upper => 2 } ] },
      start1 => { -between => \["? AND ?", [ start1 => 1], [start1 => 2] ] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", [ start3 => 'stuff'] ],
      ] },
    },
    stmt => "WHERE (
          ( start0 BETWEEN ? AND UPPER(?)         )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )",
    bind => [
      [ start0 => 1 ],
      [ start0 => 2 ],
      [ start1 => 1 ],
      [ start1 => 2 ],
      [ start3 => 'stuff' ],
    ],
    test => '-between POD test',
  },
  {
    args => { restore_old_unop_handling => 1, bindtype => 'columns' },
    where => {
      start0 => { -between => [ 1, { -upper => 2 } ] },
      start1 => { -between => \["? AND ?", [ start1 => 1], [start1 => 2] ] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", [ start3 => 'stuff'] ],
      ] },
    },
    stmt => "WHERE (
          ( start0 BETWEEN ? AND UPPER ?          )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )",
    bind => [
      [ start0 => 1 ],
      [ start0 => 2 ],
      [ start1 => 1 ],
      [ start1 => 2 ],
      [ start3 => 'stuff' ],
    ],
    test => '-between POD test',
  },
  {
    where => { 'test1.a' => { 'In', ['boom', 'bang'] } },
    stmt => ' WHERE ( test1.a IN ( ?, ? ) )',
    bind => ['boom', 'bang'],
    test => 'In (no dash, initial cap) with qualified column',
  },
  {
    where => { a => { 'between', ['boom', 'bang'] } },
    stmt => ' WHERE ( a BETWEEN ? AND ? )',
    bind => ['boom', 'bang'],
    test => 'between (no dash) with two placeholders',
  },

  {
    where => { x => { -in => [ 1 .. 3] } },
    stmt => "WHERE x IN (?, ?, ?)",
    bind => [ 1 .. 3 ],
    test => '-in with an array of scalars',
  },
  {
    where => { x => { -in => [] } },
    stmt => "WHERE 0=1",
    bind => [],
    test => '-in with an empty array',
  },
  {
    where => { x => { -in => \'( 1,2,lower(y) )' } },
    stmt => "WHERE x IN ( 1,2,lower(y) )",
    bind => [],
    test => '-in with a literal scalarref',
  },

  # note that outer parens are opened even though literal was requested below
  {
    where => { x => { -in => \['( ( ?,?,lower(y) ) )', 1, 2] } },
    stmt => "WHERE x IN ( ?,?,lower(y) )",
    bind => [1, 2],
    test => '-in with a literal arrayrefref',
  },
  {
    where => {
      status => { -in => \"(SELECT status_codes\nFROM states)" },
    },
    stmt => " WHERE status IN ( SELECT status_codes FROM states )",
    bind => [],
    test => '-in multi-line subquery test',
  },

  # check that the outer paren opener is not too agressive
  # note: this syntax *is not legal* on SQLite (maybe others)
  #       see end of https://rt.cpan.org/Ticket/Display.html?id=99503
  {
    where => { foo => { -in => \ '(SELECT 1) UNION (SELECT 2)' } },
    stmt => 'WHERE foo IN ( (SELECT 1) UNION (SELECT 2) )',
    bind => [],
    test => '-in paren-opening works on balanced pairs only',
  },

  {
    where => {
      customer => { -in => \[
        'SELECT cust_id FROM cust WHERE balance > ?',
        2000,
      ]},
      status => { -in => \'SELECT status_codes FROM states' },
    },
    stmt => "
      WHERE
            customer IN ( SELECT cust_id FROM cust WHERE balance > ? )
        AND status IN ( SELECT status_codes FROM states )
    ",
    bind => [2000],
    test => '-in POD test',
  },

  {
    where => { x => { -in => [ \['LOWER(?)', 'A' ], \'LOWER(b)', { -lower => 'c' } ] } },
    stmt => " WHERE ( x IN ( LOWER(?), LOWER(b), LOWER(?) ) )",
    bind => [qw/A c/],
    test => '-in with an array of function array refs with args',
  },
  {
    args => { restore_old_unop_handling => 1 },
    where => { x => { -in => [ \['LOWER(?)', 'A' ], \'LOWER(b)', { -lower => 'c' } ] } },
    stmt => " WHERE ( x IN ( LOWER(?), LOWER(b), LOWER ? ) )",
    bind => [qw/A c/],
    test => '-in with an array of function array refs with args',
  },
  {
    throws => qr/
      \QSQL::Abstract before v1.75 used to generate incorrect SQL \E
      \Qwhen the -IN operator was given an undef-containing list: \E
      \Q!!!AUDIT YOUR CODE AND DATA!!! (the upcoming Data::Query-based \E
      \Qversion of SQL::Abstract will emit the logically correct SQL \E
      \Qinstead of raising this exception)\E
    /x,
    where => { x => { -in => [ 1, undef ] } },
    stmt => " WHERE ( x IN ( ? ) OR x IS NULL )",
    bind => [ 1 ],
    test => '-in with undef as an element',
  },
  {
    throws => qr/
      \QSQL::Abstract before v1.75 used to generate incorrect SQL \E
      \Qwhen the -IN operator was given an undef-containing list: \E
      \Q!!!AUDIT YOUR CODE AND DATA!!! (the upcoming Data::Query-based \E
      \Qversion of SQL::Abstract will emit the logically correct SQL \E
      \Qinstead of raising this exception)\E
    /x,
    where => { x => { -in => [ 1, undef, 2, 3, undef ] } },
    stmt => " WHERE ( x IN ( ?, ?, ? ) OR x IS NULL )",
    bind => [ 1, 2, 3 ],
    test => '-in with multiple undef elements',
  },
  {
    where => { a => { -in => 42 }, b => { -not_in => 42 } },
    stmt => ' WHERE a IN ( ? ) AND b NOT IN ( ? )',
    bind => [ 42, 42 ],
    test => '-in, -not_in with scalar',
  },
  {
    where => { a => { -in => [] }, b => { -not_in => [] } },
    stmt => ' WHERE ( 0=1 AND 1=1 )',
    bind => [],
    test => '-in, -not_in with empty arrays',
  },
  {
    throws => qr/
      \QSQL::Abstract before v1.75 used to generate incorrect SQL \E
      \Qwhen the -IN operator was given an undef-containing list: \E
      \Q!!!AUDIT YOUR CODE AND DATA!!! (the upcoming Data::Query-based \E
      \Qversion of SQL::Abstract will emit the logically correct SQL \E
      \Qinstead of raising this exception)\E
    /x,
    where => { a => { -in => [42, undef] }, b => { -not_in => [42, undef] } },
    stmt => ' WHERE ( ( a IN ( ? ) OR a IS NULL ) AND b NOT IN ( ? ) AND b IS NOT NULL )',
    bind => [ 42, 42 ],
    test => '-in, -not_in with undef among elements',
  },
  {
    throws => qr/
      \QSQL::Abstract before v1.75 used to generate incorrect SQL \E
      \Qwhen the -IN operator was given an undef-containing list: \E
      \Q!!!AUDIT YOUR CODE AND DATA!!! (the upcoming Data::Query-based \E
      \Qversion of SQL::Abstract will emit the logically correct SQL \E
      \Qinstead of raising this exception)\E
    /x,
    where => { a => { -in => [undef] }, b => { -not_in => [undef] } },
    stmt => ' WHERE ( a IS NULL AND b IS NOT NULL )',
    bind => [],
    test => '-in, -not_in with just undef element',
  },
  {
    where => { a => { -in => undef } },
    throws => qr/Argument passed to the 'IN' operator can not be undefined/,
    test => '-in with undef argument',
  },

  {
    where => { -in => [ 'bob', 4, 2 ] },
    stmt => ' WHERE (bob IN (?, ?))',
    bind => [ 4, 2 ],
    test => 'Top level -in',
  },
# This works but then SQL::Abstract::Tree breaks - something for a later commit
#  {
#    where => { -in => [ { -list => [ qw(x y) ] }, { -list => [ 1, 3 ] }, { -list => [ 2, 4 ] } ] },
#    stmt => ' WHERE ((x, y) IN ((?, ?), (?, ?))',
#    bind => [ 1, 3, 2, 4 ],
#    test => 'Top level -in with list args',
#  },
  {
    where => { -between => [42, 69] },
    throws => qr/Fatal: Operator 'BETWEEN' requires/,
    test => 'Top level -between with broken args',
  },
  {
    where => {
      -between => [
        { -op => [ '+', { -ident => 'foo' }, 2 ] },
        3, 4
      ],
    },
    stmt => ' WHERE (foo + ? BETWEEN ? AND ?)',
    bind => [ 2, 3, 4 ],
    test => 'Top level -between with useful LHS',
  },
  {
    where => {
      -in => [
        { -row => [ 'x', 'y' ] },
        { -row => [ 1, 2 ] },
        { -row => [ 3, 4 ] },
      ],
    },
    stmt => ' WHERE (x, y) IN ((?, ?), (?, ?))',
    bind => [ 1..4 ],
    test => 'Complex top-level -in',
  },
  {
    where => { -is => [ 'bob', undef ] },
    stmt => ' WHERE bob IS NULL',
    bind => [],
    test => 'Top level -is ok',
  },
  {
    where => { -op => [ in => x => 1, 2, 3 ] },
    stmt => ' WHERE x IN (?, ?, ?)',
    bind => [ 1, 2, 3 ],
    test => 'Raw -op passes through correctly'
  },

);

for my $case (@in_between_tests) {
  TODO: {
    local $TODO = $case->{todo} if $case->{todo};
    local $SQL::Abstract::Test::parenthesis_significant = $case->{parenthesis_significant};
    my $label = $case->{test} || 'in-between test';

    my $sql = SQL::Abstract->new($case->{args} || {});

    if (my $e = $case->{throws}) {
      my $stmt;
      throws_ok { ($stmt) = $sql->where($case->{where}) } $e, "$label throws correctly"
        or diag dumper ({ where => $case->{where}, result => $stmt });
    }
    else {
      my ($stmt, @bind);
      lives_ok {
        warnings_are {
          ($stmt, @bind) = $sql->where($case->{where});
        } [], "$label gives no warnings";

        is_same_sql_bind(
          $stmt,
          \@bind,
          $case->{stmt},
          $case->{bind},
          "$label generates correct SQL and bind",
        ) || diag dumper ({ where => $case->{where}, exp => $sql->_expand_expr($case->{where}) });
      } || diag dumper ({ where => $case->{where}, exp => $sql->_expand_expr($case->{where}) });
    }
  }
}

done_testing;
