package SQL::Abstract::Clauses;

use strict;
use warnings;
use mro 'c3';
use base 'SQL::Abstract';

BEGIN { *puke = \&SQL::Abstract::puke }

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
  $self->{clauses_of}{update} = [ qw(update set where returning) ];
  $self->{expand}{update} = sub { shift->_expand_statement(@_) };
  $self->{render}{update} = sub { shift->_render_statement(update => @_) };
  $self->{expand_clause}{'update.update'} = sub {
    $_[0]->expand_expr($_[1], -ident)
  };
  $self->{expand_clause}{'update.set'} = '_expand_update_set_values';
  $self->{expand_clause}{'update.where'} = 'expand_expr';
  $self->{expand_clause}{'update.returning'} = sub {
    shift->_expand_maybe_list_expr(@_, -ident);
  };
  $self->{clauses_of}{delete} = [ qw(delete_from where returning) ];
  $self->{expand}{delete} = sub { shift->_expand_statement(@_) };
  $self->{render}{delete} = sub { shift->_render_statement(delete => @_) };
  $self->{expand_clause}{'delete.delete_from'} = sub {
    $_[0]->_expand_maybe_list_expr($_[1], -ident)
  };
  $self->{expand_clause}{'delete.where'} = 'expand_expr';
  $self->{expand_clause}{'delete.returning'} = sub {
    shift->_expand_maybe_list_expr(@_, -ident);
  };
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
  # a single identifier argument, so we convert it into a literal

  $clauses{select} = { -literal => [ $clauses{select}||'*' ] }
    unless ref($clauses{select});

  my ($sql, @bind) = $self->render_expr({ -select => \%clauses });
  return wantarray ? ($sql, @bind) : $sql;
}

sub update {
  my ($self, $table, $set, $where, $options) = @_;
  my %clauses;
  @clauses{qw(update set where)} = ($table, $set, $where);
  puke "Unsupported data type specified to \$sql->update"
    unless ref($clauses{set}) eq 'HASH';
  @clauses{keys %$options} = values %$options;
  my ($sql, @bind) = $self->render_expr({ -update => \%clauses });
  return wantarray ? ($sql, @bind) : $sql;
}

sub delete {
  my ($self, $table, $where, $options) = @_;
  my %clauses = (delete_from => $table, where => $where, %{$options||{}});
  my ($sql, @bind) = $self->render_expr({ -delete => \%clauses });
  return wantarray ? ($sql, @bind) : $sql;
}

1;
