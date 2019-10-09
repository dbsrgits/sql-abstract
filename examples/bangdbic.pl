use strict;
use warnings;
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
             ->$_tap(add_columns => qw(a b c))
  );
}

my $s = MySchema->connect('dbi:SQLite:dbname=:memory:');

my $rs = $s->resultset('Foo')->search({ z => 1 });

warn ${$rs->as_query}->[0]."\n";

$s->storage->ensure_connected;

$s->storage
  ->sql_maker->plugin('+ExtraClauses')->plugin('+BangOverrides');

my $rs2 = $s->resultset('Foo')->search({
  -op => [ '=', { -ident => 'outer.y' }, { -ident => 'me.x' } ]
});

warn ${$rs2->as_query}->[0]."\n";

my $rs3 = $rs2->search({}, {
  '!from' => sub { my ($sqla, $from) = @_;
    my $base = $sqla->expand_expr({ -old_from => $from });
    return [ $base, -join => [ 'wub', on => [ 'me.z' => 'wub.z' ] ] ];
  }
});

warn ${$rs3->as_query}->[0]."\n";

my $rs4 = $rs3->search({}, {
  '!with' => [ [ qw(wub x y z) ], $s->resultset('Bar')->as_query ],
});

warn ${$rs4->as_query}->[0]."\n";

my $rs5 = $rs->search({}, { select => [ { -coalesce => [ { -ident => 'x' }, { -value => 7 } ] } ] });

warn ${$rs5->as_query}->[0]."\n";

my $rs6 = $rs->search({}, { '!select' => [ { -coalesce => [ { -ident => 'x' }, { -value => 7 } ] } ] });

warn ${$rs6->as_query}->[0]."\n";
