package SQL::Abstract::ExtraClauses;

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
use mro 'c3';
use base qw(SQL::Abstract::Clauses);

BEGIN { *puke = \&SQL::Abstract::puke }

sub register_defaults {
  my $self = shift;
  $self->next::method(@_);
  $self->clauses_of(
    select => $self->clauses_of('select'), qw(group_by having)
  );
  $self->clause_expanders(
    'select.group_by', sub {
      $_[0]->_expand_maybe_list_expr($_[1], -ident)
    },
    'select.having', 'expand_expr',
  );
  foreach my $thing (qw(join from_list)) {
    $self->expander($thing => "_expand_${thing}")
         ->renderer($thing => "_render_${thing}")
  }
  $self->op_expander(as => '_expand_op_as');
  $self->expander(as => '_expand_op_as');
  $self->renderer(as => '_render_as');

  $self->clauses_of(update => sub {
    my ($self, @clauses) = @_;
    splice(@clauses, 2, 0, 'from');
    @clauses;
  });

  $self->clauses_of(delete => sub {
    my ($self, @clauses) = @_;
    splice(@clauses, 1, 0, 'using');
    @clauses;
  });

  $self->clause_expanders(
    'update.from' => '_expand_select_clause_from',
    'delete.using' => sub {
      +(using => $_[0]->_expand_from_list(undef, $_[1]));
    },
    'insert.rowvalues' => sub {
      +(from => $_[0]->expand_expr({ -values => $_[1] }));
    },
    'insert.select' => sub {
      +(from => $_[0]->expand_expr({ -select => $_[1] }));
    },
  );

  $self->renderer(keyword => sub {
    $_[0]->_sqlcase(join ' ', split '_', $_[1]);
  });
  return $self;
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
  my @args = ref($args) eq 'ARRAY' ? @$args : ($args);
  while (my $entry = shift @args) {
    if (!ref($entry) and $entry =~ /^-(.*)/) {
      if ($1 eq 'as') {
        $list[-1] = $self->expand_expr({ -as => [
          $list[-1], map +(ref($_) eq 'ARRAY' ? @$_ : $_), shift(@args)
        ]});
        next;
      }
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
  if (my $as = delete $proto{as}) {
    $proto{to} = { -as => [ $proto{to}, ref($as) eq 'ARRAY' ? @$as : $as ] };
  }
  if (defined($proto{using}) and ref(my $using = $proto{using}) ne 'HASH') {
    $proto{using} = { -row => [
      map [ $self->expand_expr($_, -ident) ],
        ref($using) eq 'ARRAY' ? @$using: $using
    ] };
  }
  my %ret = map +($_ => $self->expand_expr($proto{$_}, -ident)),
              sort keys %proto;
  return +{ -join => \%ret };
}

sub _render_from_list {
  my ($self, $list) = @_;
  return $self->join_clauses(', ', map [ $self->render_aqt($_) ], @$list);
}

sub _render_join {
  my ($self, $args) = @_;

  my @parts = (
    [ $self->render_aqt($args->{from}) ],
    [ $self->render_aqt(
        { -keyword => join '_', ($args->{type}||()), 'join' }
    ) ],
    [ $self->render_aqt(
        map +($_->{-ident} || $_->{-as} ? $_ : { -row => [ $_ ] }), $args->{to}
    ) ],
    ($args->{on} ? (
      [ $self->render_aqt({ -keyword => 'on' }) ],
      [ $self->render_aqt($args->{on}) ],
    ) : ()),
    ($args->{using} ? (
      [ $self->render_aqt({ -keyword => 'using' }) ],
      [ $self->render_aqt($args->{using}) ],
    ) : ()),
  );
  return $self->join_clauses(' ', @parts);
}

sub _expand_op_as {
  my ($self, undef, $vv, $k) = @_;
  my @as = map $self->expand_expr($_, -ident),
             (defined($k) ? ($k) : ()), ref($vv) eq 'ARRAY' ? @$vv : $vv;
  return { -as => \@as };
}

sub _render_as {
  my ($self, $args) = @_;
  my ($thing, $as, @cols) = @$args;
  return $self->join_clauses(
    ' ',
    [ $self->render_aqt($thing) ],
    [ $self->render_aqt({ -keyword => 'as' }) ],
    (@cols
      ? [ $self->join_clauses('',
            [ $self->render_aqt($as) ],
            [ '(' ],
            [ $self->join_clauses(
                ', ',
                map [ $self->render_aqt($_) ], @cols
            ) ],
            [ ')' ],
        ) ]
      : [ $self->render_aqt($as) ]
    ),
  );
}

1;
