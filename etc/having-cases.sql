
-- CASE 1
SELECT users.name, SUM(commission) AS total 
  FROM commissions
    INNER JOIN users ON ( commissions.recipient_id = users.id )
  WHERE commissions.entry_date > '2007-01-01'
  GROUP BY commissions.recipient_id
    HAVING total > 500
  ORDER BY total DESC;

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
