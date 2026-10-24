use strict;
use warnings;
use Test::More;
use SQL::Abstract::Test import => [qw(is_same_sql_bind)];

use SQL::Abstract;

# RT#156818: with array_as_in => 1, an arrayref of plain values on a column
# becomes "col IN (...)" instead of a chain of "col = ? OR col = ?", which
# some databases (MySQL) plan much worse for long lists. Anything whose
# meaning would change keeps the old OR expansion.

{
  package My::Overloaded;
  use overload q("") => sub { 'obj' }, fallback => 1;
}
my $obj = bless {}, 'My::Overloaded';

my @tests = (
  {
    where => { id => [1, 2, 3] },
    stmt  => 'WHERE id IN ( ?, ?, ? )',
    bind  => [1, 2, 3],
    test  => 'plain values become IN',
  },
  {
    where => { id => [-or => 1, 2] },
    stmt  => 'WHERE id IN ( ?, ? )',
    bind  => [1, 2],
    test  => 'explicit -or prefix becomes IN',
  },
  {
    where => { id => [$obj, 2] },
    stmt  => 'WHERE id IN ( ?, ? )',
    bind  => [$obj, 2],
    test  => 'blessed values are bind values like plain scalars',
  },
  {
    where => { id => [1, undef, 2] },
    stmt  => 'WHERE ( id IN ( ?, ? ) OR id IS NULL )',
    bind  => [1, 2],
    test  => 'undef elements become a separate IS NULL',
  },
  {
    where => { id => [undef, 1, 2, undef] },
    stmt  => 'WHERE ( id IN ( ?, ? ) OR id IS NULL )',
    bind  => [1, 2],
    test  => 'several undefs give a single IS NULL',
  },
  {
    where => { a => 1, id => [1, 2] },
    stmt  => 'WHERE a = ? AND id IN ( ?, ? )',
    bind  => [1, 1, 2],
    test  => 'works next to other columns',
  },
  {
    where => { -or => [ { id => [1, 2] }, { name => [qw(x y)] } ] },
    stmt  => 'WHERE id IN ( ?, ? ) OR name IN ( ?, ? )',
    bind  => [1, 2, qw(x y)],
    test  => 'works inside nested conditions',
  },

  # cases that keep the original expansion
  {
    where => { id => [1] },
    stmt  => 'WHERE id = ?',
    bind  => [1],
    test  => 'a single value stays an equality',
  },
  {
    where => { id => [1, undef] },
    stmt  => 'WHERE ( id = ? OR id IS NULL )',
    bind  => [1],
    test  => 'a single value plus undef stays as before',
  },
  {
    where => { id => [undef, undef] },
    stmt  => 'WHERE ( id IS NULL OR id IS NULL )',
    bind  => [],
    test  => 'only undefs stay as before',
  },
  {
    where => { id => [] },
    stmt  => 'WHERE 0=1',
    bind  => [],
    test  => 'an empty arrayref stays false',
  },
  {
    where => { id => [-and => 1, 2] },
    stmt  => 'WHERE ( id = ? AND id = ? )',
    bind  => [1, 2],
    test  => '-and prefix is not turned into IN',
  },
  {
    where => { id => [{ '>' => 1 }, 2] },
    stmt  => 'WHERE ( id > ? OR id = ? )',
    bind  => [1, 2],
    test  => 'hashref elements are not turned into IN',
  },
  {
    where => { id => [\'NOW()', 2] },
    stmt  => 'WHERE ( id NOW() OR id = ? )',
    bind  => [2],
    test  => 'literal SQL elements are not turned into IN',
  },
  {
    where => { id => [[1, 2], 3] },
    stmt  => 'WHERE ( id IN ( ?, ? ) OR id = ? )',
    bind  => [1, 2, 3],
    test  => 'a nested arrayref is not flattened into the outer IN',
  },
  {
    where => { id => { '=' => [1, 2] } },
    stmt  => 'WHERE ( id = ? OR id = ? )',
    bind  => [1, 2],
    test  => 'an explicit = operator is left alone',
  },
);

for my $t (@tests) {
  my $sql = SQL::Abstract->new(array_as_in => 1);
  my ($stmt, @bind) = $sql->where($t->{where});
  is_same_sql_bind($stmt, \@bind, $t->{stmt}, $t->{bind}, $t->{test});
}

{
  my $sql = SQL::Abstract->new;
  my ($stmt, @bind) = $sql->where({ id => [1, 2, 3] });
  is_same_sql_bind(
    $stmt, \@bind,
    'WHERE ( id = ? OR id = ? OR id = ? )', [1, 2, 3],
    'off by default',
  );
}

{
  my $sql = SQL::Abstract->new(array_as_in => 1, cmp => 'like');
  my ($stmt, @bind) = $sql->where({ id => [1, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'WHERE ( id LIKE ? OR id LIKE ? )', [1, 2],
    'a non-equality cmp keeps the OR expansion',
  );
}

{
  my $sql = SQL::Abstract->new(array_as_in => 1, logic => 'and');
  my ($stmt, @bind) = $sql->where({ id => [1, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'WHERE ( id = ? AND id = ? )', [1, 2],
    'logic => and keeps the AND expansion',
  );
}

{
  my $sql = SQL::Abstract->new(array_as_in => 1, bindtype => 'columns');
  my ($stmt, @bind) = $sql->where({ id => [1, undef, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'WHERE ( id IN ( ?, ? ) OR id IS NULL )', [[id => 1], [id => 2]],
    'bindtype => columns',
  );
}

{
  my $sql = SQL::Abstract->new(array_as_in => 1);
  my ($stmt, @bind) = $sql->select('t', '*', { id => [1, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'SELECT * FROM t WHERE id IN ( ?, ? )', [1, 2],
    'select',
  );
  ($stmt, @bind) = $sql->update('t', { x => 1 }, { id => [1, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'UPDATE t SET x = ? WHERE id IN ( ?, ? )', [1, 1, 2],
    'update',
  );
  ($stmt, @bind) = $sql->delete('t', { id => [1, 2] });
  is_same_sql_bind(
    $stmt, \@bind,
    'DELETE FROM t WHERE id IN ( ?, ? )', [1, 2],
    'delete',
  );
}

done_testing;
