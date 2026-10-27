use strict;
use warnings;

use Test::More;
use Test::Exception;
use SQL::Abstract;
use SQL::Abstract::Test import => [qw/is_same_sql_bind/];


for my $q ('', '"') {
  my $sql_maker = SQL::Abstract->new(
    quote_char => $q,
    name_sep => $q ? '.' : '',
  );

  throws_ok {
    $sql_maker->where({ foo => { -ident => undef } })
  } qr/-ident requires a single plain scalar argument/;

  throws_ok {
    local $sql_maker->{disable_old_special_ops} = 1;
    $sql_maker->where({'-or' => [{'-ident' => 'foo'},'foo']})
  } qr/Illegal.*top-level/;

  throws_ok {
    local $sql_maker->{disable_old_special_ops} = 1;
    $sql_maker->where({'-or' => [{'-ident' => 'foo'},{'=' => \'bozz'}]})
  } qr/Illegal.*top-level/;

  {
    # RT#136984: an arrayref of -bool conditions (as produced by e.g.
    # DBIC search([{ -bool => 'f1' }, { -bool => 'f2' }])) must not be
    # rejected as an illegal top-level op under disable_old_special_ops
    local $sql_maker->{disable_old_special_ops} = 1;
    my ($sql, @bind) = $sql_maker->where([{ -bool => 'f1' }, { -bool => 'f2' }]);
    is_same_sql_bind(
      $sql, \@bind,
      "WHERE ( ( ${q}f1${q} OR ${q}f2${q} ) )",
      [],
    );
  }

  my ($sql, @bind) = $sql_maker->select('artist', '*', { 'artist.name' => { -ident => 'artist.pseudonym' } } );
  is_same_sql_bind (
    $sql,
    \@bind,
    "SELECT *
      FROM ${q}artist${q}
      WHERE ${q}artist${q}.${q}name${q} = ${q}artist${q}.${q}pseudonym${q}
    ",
    [],
  );

  ($sql, @bind) = $sql_maker->update('artist',
    { 'artist.name' => { -ident => 'artist.pseudonym' } },
    { 'artist.name' => { '!=' => { -ident => 'artist.pseudonym' } } },
  );
  is_same_sql_bind (
    $sql,
    \@bind,
    "UPDATE ${q}artist${q}
      SET ${q}artist${q}.${q}name${q} = ${q}artist${q}.${q}pseudonym${q}
      WHERE ${q}artist${q}.${q}name${q} != ${q}artist${q}.${q}pseudonym${q}
    ",
    [],
  );

  ($sql) = $sql_maker->select(
    \(my $from = 'foo JOIN bar ON foo.bar_id = bar.id'),
    [ { -ident => [ 'foo', 'name' ] }, { -ident => [ 'bar', '*' ] } ]
  );

  is_same_sql_bind(
    $sql,
    undef,
    "SELECT ${q}foo${q}.${q}name${q}, ${q}bar${q}.*
     FROM $from"
  );
}

{
  # quote_char without name_sep: dotted names are split on '.', so each
  # part gets its own quotes (not "a""b", which is the identifier a"b)
  my $sql_maker = SQL::Abstract->new(quote_char => '"');

  my ($sql, @bind) = $sql_maker->select(
    't.x', [ 'a.b', { -ident => [ 'c', 'd' ] } ], { 'e.f' => 1 },
  );
  is_same_sql_bind(
    $sql, \@bind,
    'SELECT "a"."b", "c"."d" FROM "t"."x" WHERE "e"."f" = ?', [ 1 ],
    'quote_char without name_sep quotes each part',
  );

  is(
    $sql_maker->_quote('a.b'), '"a"."b"',
    '_quote on a plain string splits it the same way',
  );

  # an empty name_sep keeps dotted names as one identifier
  $sql_maker = SQL::Abstract->new(quote_char => '"', name_sep => '');
  ($sql) = $sql_maker->select('t.x', [ 'a.b', { -ident => [ 'c', 'd' ] } ]);
  is_same_sql_bind(
    $sql, undef,
    'SELECT "a.b", "c"."d" FROM "t.x"', undef,
    'empty name_sep: plain names stay whole, explicit parts are joined with .',
  );
}

done_testing;
