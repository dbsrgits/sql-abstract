use strict;
use warnings;
use Test::More;

use SQL::Abstract::Test import => ['is_same_sql_bind'];

use SQL::Abstract;

my $sqlmaker = SQL::Abstract->new(special_ops => [

  # special op for MySql MATCH (field) AGAINST(word1, word2, ...)
  {regex => qr/^match$/i,
   handler => sub {
     my ($self, $field, $op, $arg) = @_;
     $arg = [$arg] if not ref $arg;
     my $label         = $self->_quote($field);
     my ($placeholder) = $self->_convert('?');
     my $placeholders  = join ", ", (($placeholder) x @$arg);
     my $sql           = $self->_sqlcase('match') . " ($label) "
                       . $self->_sqlcase('against') . " ($placeholders) ";
     my @bind = $self->_bindtype($field, @$arg);
     return ($sql, @bind);
     }
   },

  # special op for Basis+ NATIVE
  {regex => qr/^native$/i,
   handler => sub {
     my ($self, $field, $op, $arg) = @_;
     $arg =~ s/'/''/g;
     my $sql = "NATIVE (' $field $arg ')";
     return ($sql);
     }
   },

  # PRIOR op from DBIx::Class::SQLMaker::Oracle

  {
    regex => qr/^prior$/i,
    handler => sub {
      my ($self, $lhs, $op, $rhs) = @_;
      my ($sql, @bind) = $self->_recurse_where ($rhs);

      $sql = sprintf ('%s = %s %s ',
        $self->_convert($self->_quote($lhs)),
        $self->_sqlcase ($op),
        $sql
      );

      return ($sql, @bind);
    },
  },

], unary_ops => [
  # unary op from Mojo::Pg
  {regex => qr/^json$/i,
   handler => sub { '?', { json => $_[2] } }
  },
]);

my @tests = (

  #1
  { where => {foo => {-match => 'foo'},
              bar => {-match => [qw/foo bar/]}},
    stmt  => " WHERE ( MATCH (bar) AGAINST (?, ?) AND MATCH (foo) AGAINST (?) )",
    bind  => [qw/foo bar foo/],
  },

  #2
  { where => {foo => {-native => "PH IS 'bar'"}},
    stmt  => " WHERE ( NATIVE (' foo PH IS ''bar'' ') )",
    bind  => [],
  },

  #3
  { where => { foo => { -json => { bar => 'baz' } } },
    stmt => "WHERE foo = ?",
    bind => [ { json => { bar => 'baz' } } ],
  },

  #4
  { where => { foo => { '@>' => { -json => { bar => 'baz' } } } },
    stmt => "WHERE foo @> ?",
    bind => [ { json => { bar => 'baz' } } ],
  },

  # Verify inconsistent behaviour from DBIx::Class:SQLMaker::Oracle works
  # (unary use of special op is not equivalent to special op + =)
  {
    where => {
      foo_id => { '=' => { '-prior' => { -ident => 'bar_id' } } },
      baz_id => { '-prior' => { -ident => 'quux_id' } },
    },
    stmt        => ' WHERE ( baz_id = PRIOR quux_id AND foo_id = ( PRIOR bar_id ) )',
    bind        => [],
  },
);

for (@tests) {

  my($stmt, @bind) = $sqlmaker->where($_->{where}, $_->{order});
  is_same_sql_bind($stmt, \@bind, $_->{stmt}, $_->{bind});
}

done_testing;
