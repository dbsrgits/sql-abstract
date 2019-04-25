package DBIx::Class::SQLMaker::SQLA2Support;

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
use mro 'c3';
use base qw(
  DBIx::Class::SQLMaker
  SQL::Abstract::ExtraClauses
);

sub select {
  my $self = shift;
  my ($sql, @bind) = $self->next::method(@_);
  my (undef, undef, undef, $attrs) = @_;
  if (my $with = delete $attrs->{with}) {
    my ($wsql, @wbind) = @{ $self->render_statement({
      -select => { with => $with }
    }) };
    unshift @bind, @wbind;
    $sql = "${wsql} ${sql}";
  }
  return wantarray ? ($sql, @bind) : $sql;
}

1;
