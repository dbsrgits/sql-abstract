
-- CASE 1
SELECT users.name, SUM(commission) AS total 
  FROM commissions
    INNER JOIN users ON ( commissions.recipient_id = users.id )
  WHERE commissions.entry_date > '2007-01-01'
  GROUP BY commissions.recipient_id
    HAVING total > 500
  ORDER BY total DESC;

order_by { $_->total }
  select { $_->users->name, [ total => sum($_->aggregates->commission) ] }
   where { sum($_->aggregates->commission) > 500 }
group_by { $_->commissions->recipient_id }
    join { $_->users->id == $_->commissions->recipient_id }
      [ users => expr { $_->users  } ],
      [ commission => expr { $_->commissions } ];

my $total = [ -sum => [ -name => 'commission' ] ];

[
  -select,
  [
    -list,
    [ -name => qw(users name) ],
    $total
  [
    -where,
    [ '>', $total, [ -value, 500 ] ],
    [
      -group_by,
      [ -name, qw(commissions recipient_id) ],
      [
        -where,
        [ '>', [ -name, qw(commissions entry_date) ], [ -value, '2007-01-01' ] ],
        [
          -join,
          ...
      ],
    ],
  ],
  ],
]

-- CASE 2
SELECT users.name, aggregates.total FROM (
       SELECT recipient_id, SUM(commission) AS total
       FROM commissions
       WHERE commissions.entry_date > '2007-01-01'
       GROUP BY commissions.recipient_id
       HAVING total > 500
   ) AS aggregates
INNER JOIN users ON(aggregates.recipient_id = users.id)
ORDER BY aggregates.total DESC;

order_by { $_->aggregates->total }
  select { $_->users->name, $_->aggregates->total }
    join { $_->users->id == $_->aggregates->recipient_id }
      [ users => expr { $_->users  } ],
      [ aggregates =>
          expr {
              select { $_->recipient_id, [ total => sum($_->commission) ] }
               where { sum($_->commission) > 500 }
            group_by { $_->recipient_id }
               where { $_->entry_date > '2007-01-01' }
                expr { $_->commissions }
          }
      ];
 

-- CASE 3
SELECT users.name, aggregates.total FROM (
       SELECT recipient_id, SUM(commission) AS total
       FROM commissions
       WHERE commissions.entry_date > '2007-01-01'
       GROUP BY commissions.recipient_id
   ) AS aggregates
INNER JOIN users ON(aggregates.recipient_id = users.id)
WHERE aggregates.total > 500
ORDER BY aggregates.total DESC


order_by { $_->aggregates->total }
  select { $_->users->name, $_->aggregates->total }
   where { $_->aggregates->total > 500 }
    join { $_->users->id == $_->aggregates->recipient_id }
      [ users => expr { $_->users  } ],
      [ aggregates =>
          expr {
              select { $_->recipient_id, [ total => sum($_->commission) ] }
            group_by { $_->recipient_id }
               where { $_->entry_date > '2007-01-01' }
                expr { $_->commissions }
          }
      ];
