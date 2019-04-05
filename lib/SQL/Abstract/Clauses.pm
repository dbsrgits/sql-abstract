package SQL::Abstract::Clauses;

use strict;
use warnings;
use mro 'c3';
use base 'SQL::Abstract';

sub new {
  shift->next::method(@_)->register_defaults
}

sub register_defaults {
  my ($self) = @_;
  $self->{clauses_of}{select} = [ qw(select from where order_by) ];
  $self->{expand}{select} = sub { shift->_expand_statement(@_) };
  $self->{render}{select} = sub { shift->_render_statement(select => @_) };
  $self->{expand_clause}{'select.select'} = sub {
    $_[0]->_expand_maybe_list_expr($_[1], -ident)
  };
  $self->{expand_clause}{'select.from'} = sub {
    $_[0]->_expand_maybe_list_expr($_[1], -ident)
  };
  $self->{expand_clause}{'select.where'} = 'expand_expr';
  $self->{expand_clause}{'select.order_by'} = '_expand_order_by';
  return $self;
}

sub _expand_statement {
  my ($self, $type, $args) = @_;
  my $ec = $self->{expand_clause};
  return +{ "-${type}" => +{
    map +($_ => (do {
      my $val = $args->{$_};
      if (defined($val) and my $exp = $ec->{"${type}.$_"}) {
        $self->$exp($val);
      } else {
        $val;
      }
    })), sort keys %$args
  } };
}

sub _render_statement {
  my ($self, $type, $args) = @_;
  my @parts;
  foreach my $clause (@{$self->{clauses_of}{$type}}) {
    next unless my $clause_expr = $args->{$clause};
    local $self->{convert_where} = $self->{convert} if $clause eq 'where';
    my ($sql, @bind) = $self->render_aqt($clause_expr);
    next unless defined($sql) and length($sql);
    push @parts, [
      $self->_sqlcase(join ' ', split '_', $clause).' '.$sql,
      @bind
    ];
  }
  return $self->_join_parts(' ', @parts);
}

sub select {
  my ($self, @args) = @_;
  my %clauses;
  @clauses{qw(from select where order_by)} = @args;
  # This oddity is to literalify since historically SQLA doesn't quote
  # a single identifier argument, and the .'' is to copy $clauses{select}
  # before taking a reference to it to avoid making a reference loop
  $clauses{select}= \(($clauses{select}||'*').'')
    unless ref($clauses{select});
  my ($sql, @bind) = $self->render_expr({ -select => \%clauses });
  return wantarray ? ($sql, @bind) : $sql;
}

1;
