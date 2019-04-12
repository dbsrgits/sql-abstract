package SQL::Abstract::ExtraClauses;

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
use mro 'c3';
use base qw(SQL::Abstract::Clauses);

BEGIN { *puke = \&SQL::Abstract::puke }

sub new {
  my ($proto, @args) = @_;
  my $new = $proto->next::method(@args);
  $new->{clauses_of}{select} = [
    @{$new->{clauses_of}{select}}, qw(group_by having)
  ];
  $new->{expand_clause}{'select.group_by'} = sub {
    $_[0]->_expand_maybe_list_expr($_[1], -ident)
  };
  $new->{expand_clause}{'select.having'} = sub {
    $_[0]->expand_expr($_[1])
  };
  $new->{expand}{from_list} = '_expand_from_list';
  $new->{render}{from_list} = '_render_from_list';
  $new->{expand}{join} = '_expand_join';
  $new->{render}{join} = '_render_join';
  return $new;
}

sub _expand_select_clause_from {
  my ($self, $from) = @_;
  +(from => $self->_expand_from_list(undef, $from));
}

sub _expand_from_list {
  my ($self, undef, $args) = @_;
  if (ref($args) eq 'HASH') {
    return { -from_list => [ $self->expand_expr($args) ] };
  }
  my @list;
  my @args = ref($args) ? @$args : ($args);
  while (my $entry = shift @args) {
    if (!ref($entry) and $entry =~ /^-/) {
      $entry = { $entry => shift @args };
    }
    my $aqt = $self->expand_expr($entry, -ident);
    if ($aqt->{-join} and not $aqt->{-join}{from}) {
      $aqt->{-join}{from} = pop @list;
    }
    push @list, $aqt;
  }
  return { -from_list => \@list };
}

sub _expand_join {
  my ($self, undef, $args) = @_;
  my %proto = (
    ref($args) eq 'HASH'
      ? %$args
      : (to => $args->[0], @{$args}[1..$#$args])
  );
  my %ret = map +($_ => $self->expand_expr($proto{$_}, -ident)),
              sort keys %proto;
  return +{ -join => \%ret };
}

sub _render_from_list {
  my ($self, $list) = @_;
  return $self->_join_parts(', ', map [ $self->render_aqt($_) ], @$list);
}

sub _render_join {
  my ($self, $args) = @_;

  my @parts = (
    [ $self->render_aqt($args->{from}) ],
    [ $self->_sqlcase(
        ($args->{type}
          ? join(' ', split '_', $args->{type}).' '
          : ''
        )
        .'join'
      )
    ],
    [ $self->render_aqt($args->{to}) ],
    ($args->{on} ? (
      [ $self->_sqlcase('on') ],
      [ $self->render_aqt($args->{on}) ],
    ) : ()),
    ($args->{using} ? (
      [ $self->_sqlcase('using') ],
      [ $self->render_aqt($args->{using}) ],
    ) : ()),
  );
  return $self->_join_parts(' ', @parts);
}

1;
