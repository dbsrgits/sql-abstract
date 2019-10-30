use strict;
use warnings;
use Devel::Dwarn;
use With::Roles;
{
  package MySchema;
  use Object::Tap;
  use base qw(DBIx::Class::Schema);
  use DBIx::Class::ResultSource::Table;
  __PACKAGE__->register_source(
    Foo => DBIx::Class::ResultSource::Table->new({ name => 'foo' })
             ->$_tap(add_columns => qw(x y z))
  );
  __PACKAGE__->register_source(
    Bar => DBIx::Class::ResultSource::Table->new({ name => 'bar' })
             ->$_tap(add_columns => qw(x y1 y2 z))
  );
}
{
  package MyScratchpad;
  use DBIx::Class::SQLMaker::Role::SQLA2Passthrough qw(on);
  MySchema->source('Foo')->add_relationship(bars => 'Bar' => on {
    +{ 'foreign.x' => 'self.x',
       'foreign.y1' => { '<=', 'self.y' },
       'foreign.y2' => { '>=', 'self.y' },
    };
  });
}

{
  package DBIx::Class::SQLMakerNG;

  use strict;
  use warnings;

  require DBIx::Class::SQLMaker::ClassicExtensions;
  require SQL::Abstract;
  require SQL::Abstract::Classic;

  our @ISA = qw(
    DBIx::Class::SQLMaker::ClassicExtensions
    SQL::Abstract
    SQL::Abstract::Classic
  );
}

my $s = MySchema->connect('dbi:SQLite:dbname=:memory:', undef, undef, { on_connect_call => [ [ rebase_sqlmaker => 'DBIx::Class::SQLMakerNG' ] ] } );

::Dwarn([ $s->source('Foo')->columns ]);

my $rs = $s->resultset('Foo')->search({ z => 1 });

::Dwarn(${$rs->as_query}->[0]);

$s->storage->ensure_connected;

$s->storage
  ->sql_maker
  ->with::roles('DBIx::Class::SQLMaker::Role::SQLA2Passthrough')
  ->plugin('+ExtraClauses')
  ->plugin('+BangOverrides');

# ideally his should not be needed: both plugin() and with::roles() ought
# to preserve the original mro::get_mro value, but fixup here for now
mro::set_mro( ref( $s->storage->sql_maker ), 'c3' );

::Dwarn {
  actual_working_composite_mro => mro::get_linear_isa( ref($s->storage->sql_maker) ),
  unadjusted_default_composite_mro => mro::get_linear_isa( ref($s->storage->sql_maker), 'dfs' ),
};

my $rs2 = $s->resultset('Foo')->search({
  -op => [ '=', { -ident => 'outer.x' }, { -ident => 'me.y' } ]
}, {
  'select' => [ 'me.x', { -ident => 'me.z' } ],
  '!with' => [ outer => $rs->get_column('x')->as_query ],
});

::Dwarn(${$rs2->as_query}->[0]);

my $rs3 = $s->resultset('Foo')
            ->search({}, { prefetch => 'bars' });

::Dwarn(${$rs3->as_query}->[0]);

$s->source('Foo')->result_class('DBIx::Class::Core');
$s->source('Foo')->set_primary_key('x');

my $rs4 = $s->resultset('Foo')->new_result({ x => 1, y => 2 })
            ->search_related('bars');

::Dwarn(${$rs4->as_query}->[0]);
