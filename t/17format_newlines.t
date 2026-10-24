use strict;
use warnings;

use Test::More;
use SQL::Abstract::Test import => [qw(is_same_sql)];
use SQL::Abstract::Tree;

# indentmap entries for 'and', 'or' and ',' put AND / OR conditions and the
# items of a clause's comma list on lines of their own

sub fmt {
  my ($indentmap, $sql, %args) = @_;
  my $out = SQL::Abstract::Tree->new({
    profile              => 'console_monochrome',
    fill_in_placeholders => 0,
    ($indentmap ? (indentmap => $indentmap) : ()),
    %args,
  })->format($sql);
  # the formatter leaves a space in front of some newlines - not relevant here
  $out =~ s/ +$//mg;
  return $out;
}

sub chomped { my $s = shift; chomp $s; $s }

my $all = { and => 1, or => 1, ',' => 1 };

my $sql = 'SELECT a, b, c FROM t WHERE x = 1 AND y = 2 OR z = 3 ORDER BY a, b';

is fmt($all, $sql), chomped(<<'EOS'), 'AND, OR and clause lists on their own lines';
SELECT
  a,
  b,
  c
  FROM t
WHERE x = 1
  AND y = 2
  OR z = 3
ORDER BY
  a,
  b
EOS

is fmt({ and => 1, or => 1 }, $sql), chomped(<<'EOS'), 'only AND / OR';
SELECT a, b, c
  FROM t
WHERE x = 1
  AND y = 2
  OR z = 3
ORDER BY a, b
EOS

is fmt({ ',' => 1 }, $sql), chomped(<<'EOS'), 'only clause lists';
SELECT
  a,
  b,
  c
  FROM t
WHERE x = 1 AND y = 2 OR z = 3
ORDER BY
  a,
  b
EOS

is fmt(undef, $sql), chomped(<<'EOS'), 'profile default is unchanged';
SELECT a, b, c
  FROM t
WHERE x = 1 AND y = 2 OR z = 3
ORDER BY a, b
EOS

is fmt($all,
  'SELECT a FROM t JOIN u ON u.id = t.id AND u.x = ? WHERE ( p = 1 OR q = 2 ) AND r = 3'
), chomped(<<'EOS'), 'indented below their clause (ON) and inside parenthesis, a single select column is no list';
SELECT a
  FROM t
  JOIN u
    ON u.id = t.id
      AND u.x = ?
WHERE ( p = 1
      OR q = 2 )
  AND r = 3
EOS

is fmt($all,
  'SELECT coalesce(a, 0), b FROM t WHERE c IN ( 1, 2, 3 )'
), chomped(<<'EOS'), 'function arguments and IN lists stay on one line';
SELECT
  coalesce( a, 0 ),
  b
  FROM t
WHERE c IN ( 1, 2, 3 )
EOS

is fmt({ and => 1 },
  'SELECT a FROM t WHERE x IN ( SELECT y FROM z WHERE p = 1 AND q = 2 )'
), chomped(<<'EOS'), 'subquery';
SELECT a
  FROM t
WHERE x IN (
    SELECT y
      FROM z
    WHERE p = 1
      AND q = 2
   )
EOS

is fmt($all, 'UPDATE t SET a = ?, b = ? WHERE id = ?'), chomped(<<'EOS'), 'SET list';
UPDATE t
  SET
    a = ?,
    b = ?
WHERE id = ?
EOS

is fmt({ and => 2 }, 'SELECT a FROM t WHERE x = 1 AND y = 2'), chomped(<<'EOS'), 'the number is the indent';
SELECT a
  FROM t
WHERE x = 1
    AND y = 2
EOS

# without a newline (no profile) the entries have nothing to do
is(
  SQL::Abstract::Tree->new({ indentmap => $all })->format($sql),
  'SELECT a, b, c FROM t WHERE x = 1 AND y = 2 OR z = 3 ORDER BY a, b',
  'no newline configured: plain one-line output',
);

# the formatted SQL is still the same SQL
for my $q (
  $sql,
  'SELECT a FROM t JOIN u ON u.id = t.id AND u.x = ? WHERE ( p = 1 OR q = 2 ) AND r = 3',
  'SELECT a FROM t WHERE x IN ( SELECT y FROM z WHERE p = 1 AND q = 2 )',
  'UPDATE t SET a = ?, b = ? WHERE id = ?',
) {
  is_same_sql fmt($all, $q), $q, "same SQL after formatting: $q";
}

# merging into a profile keeps the rest of its indentmap, and does not leak
# into the next object built from that profile
{
  my $t = SQL::Abstract::Tree->new({ profile => 'console', indentmap => { and => 1 } });
  is $t->indentmap->{and}, 1, 'own entry is there';
  is $t->indentmap->{from}, 1, 'profile entries are kept';
  ok !exists SQL::Abstract::Tree->new({ profile => 'console' })->indentmap->{and},
    'profile itself is not modified';
}

done_testing;
