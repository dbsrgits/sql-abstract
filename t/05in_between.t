use strict;
use warnings;
use Test::More;
use Test::Warn;
use Test::Exception;
use SQL::Abstract::Test import => [qw(is_same_sql_bind diag_where)];

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
    parenthesis_significant => 1,
    where => { x => { -in => [ 1 .. 3] } },
    stmt => "WHERE ( x IN (?, ?, ?) )",
    bind => [ 1 .. 3],
    test => '-in with an array of scalars',
  },
  {
    parenthesis_significant => 1,
    where => { x => { -in => [] } },
    stmt => "WHERE ( 0=1 )",
    bind => [],
    test => '-in with an empty array',
  },
  {
    parenthesis_significant => 1,
    where => { x => { -in => \'( 1,2,lower(y) )' } },
    stmt => "WHERE ( x IN ( 1,2,lower(y) ) )",
    bind => [],
    test => '-in with a literal scalarref',
  },

  # note that outer parens are opened even though literal was requested below
  {
    parenthesis_significant => 1,
    where => { x => { -in => \['( ( ?,?,lower(y) ) )', 1, 2] } },
    stmt => "WHERE ( x IN ( ?,?,lower(y) ) )",
    bind => [1, 2],
    test => '-in with a literal arrayrefref',
  },
  {
    parenthesis_significant => 1,
    where => {
      status => { -in => \"(SELECT status_codes\nFROM states)" },
    },
    stmt => " WHERE ( status IN ( SELECT status_codes FROM states )) ",
    bind => [],
    test => '-in multi-line subquery test',
  },
  {
    parenthesis_significant => 1,
    where => {
      customer => { -in => \[
        'SELECT cust_id FROM cust WHERE balance > ?',
        2000,
      ]},
      status => { -in => \'SELECT status_codes FROM states' },
    },
    stmt => "
      WHERE ((
            customer IN ( SELECT cust_id FROM cust WHERE balance > ? )
        AND status IN ( SELECT status_codes FROM states )
      ))
    ",
    bind => [2000],
    test => '-in POD test',
  },

  {
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
);

for my $case (@in_between_tests) {
  TODO: {
    local $TODO = $case->{todo} if $case->{todo};
    local $SQL::Abstract::Test::parenthesis_significant = $case->{parenthesis_significant};

    my $sql = SQL::Abstract->new ($case->{args} || {});

    if (my $e = $case->{throws}) {
      throws_ok { $sql->where($case->{where}) } $e;
    }
    else {
      my ($stmt, @bind);
      warnings_are {
        ($stmt, @bind) = $sql->where($case->{where});
      } [], 'No warnings within in-between tests';

      is_same_sql_bind(
        $stmt,
        \@bind,
        $case->{stmt},
        $case->{bind},
      ) || diag_where ( $case->{where} );
    }
  }
}

done_testing;
