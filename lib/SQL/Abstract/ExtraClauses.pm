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
  my @clauses = $self->clauses_of('select');
  my @before_setop;
  CLAUSE: foreach my $idx (0..$#clauses) {
    if ($clauses[$idx] eq 'order_by') {
      @before_setop = @clauses[0..$idx-1];
      splice(@clauses, $idx, 0, qw(setop group_by having));
      last CLAUSE;
    }
  }
  die "Huh?" unless @before_setop;
  $self->clauses_of(select => 'with', @clauses);
  $self->clause_expanders(
    'select.group_by', sub {
      $_[0]->_expand_maybe_list_expr($_[2], -ident)
    },
    'select.having', sub { $_[0]->expand_expr($_[2]) },
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
      +(using => $_[0]->_expand_from_list(undef, $_[2]));
    },
    'insert.rowvalues' => sub {
      +(from => $_[0]->expand_expr({ -values => $_[2] }));
    },
    'insert.select' => sub {
      +(from => $_[0]->expand_expr({ -select => $_[2] }));
    },
  );

  # set ops
  $self->wrap_expander(select => sub {
    my $orig = shift;
    sub {
      my $self = shift;
      my $exp = $self->$orig(@_);
      return $exp unless my $setop = (my $sel = $exp->{-select})->{setop};
      if (my @keys = grep $sel->{$_}, @before_setop) {
        my %inner; @inner{@keys} = delete @{$sel}{@keys};
        unshift @{(values(%$setop))[0]{queries}},
          { -select => \%inner };
      }
      return $exp;
    }
  });
  my $expand_setop = sub {
    my ($self, $setop, $args) = @_;
    +{ "-${setop}" => {
         %$args,
         queries => [ map $self->expand_expr($_), @{$args->{queries}} ],
    } };
  };
  $self->expanders(map +($_ => $expand_setop), qw(union intersect except));

  $self->clause_renderer('select.setop' => sub {
    my ($self, undef, $setop) = @_;
    $self->render_aqt($setop);
  });

  $self->renderer($_ => sub {
    my ($self, $setop, $args) = @_;
    $self->join_query_parts(
      ' '.$self->format_keyword(join '_', $setop, ($args->{type}||())).' ',
      map [ $self->render_aqt($_) ], @{$args->{queries}}
    );
  }) for qw(union intersect except);

  my $setop_expander = sub {
    my ($self, $setop, $args) = @_;
    my ($op, $type) = split '_', $setop;
    +(setop => $self->expand_expr({
      "-${op}" => {
        ($type ? (type => $type) : ()),
        queries => (ref($args) eq 'ARRAY' ? $args : [ $args ])
      }
    }));
  };

  $self->clause_expanders(
    map +($_ => $setop_expander),
      map "select.${_}",
        map +($_, "${_}_all", "${_}_distinct"),
          qw(union intersect except)
  );

  $self->clause_expander('select.with' => my $with_expander = sub {
    my ($self, $name, $with) = @_;
    my (undef, $type) = split '_', $name;
    if (ref($with) eq 'HASH') {
      return +{
        %$with,
        queries => [ map $self->expand_expr($_), @{$with->{queries}} ]
      }
    }
    my @with = @$with;
    my @exp;
    while (my ($name, $query) = splice @with, 0, 2) {
      my @n = map $self->expand_expr($_, -ident),
                ref($name) eq 'ARRAY' ? @$name : $name;
      push @exp, [
        \@n,
        $self->expand_expr($query)
      ];
    }
    return +(with => { ($type ? (type => $type) : ()), queries => \@exp });
  });
  $self->clause_expander('select.with_recursive', $with_expander);
  $self->clause_renderer('select.with' => sub {
    my ($self, undef, $with) = @_;
    my $q_part = [ $self->join_query_parts(', ',
      map {
        my ($alias, $query) = @$_;
        [ $self->join_query_parts(' ',
            [ $self->_render_alias($alias) ],
            [ $self->format_keyword('as') ],
            [ $self->render_aqt($query) ],
        ) ]
      } @{$with->{queries}}
    ) ];
    return $self->join_query_parts(' ',
      [ $self->format_keyword(join '_', 'with', ($with->{type}||'')) ],
      $q_part,
    );
  });

  return $self;
}

sub format_keyword { $_[0]->_sqlcase(join ' ', split '_', $_[1]) }

sub _expand_select_clause_from {
  my ($self, undef, $from) = @_;
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
  my ($self, undef, $list) = @_;
  return $self->join_query_parts(', ', map [ $self->render_aqt($_) ], @$list);
}

sub _render_join {
  my ($self, undef, $args) = @_;

  my @parts = (
    [ $self->render_aqt($args->{from}) ],
    [ $self->format_keyword(join '_', ($args->{type}||()), 'join') ],
    [ $self->render_aqt(
        map +($_->{-ident} || $_->{-as} ? $_ : { -row => [ $_ ] }), $args->{to}
    ) ],
    ($args->{on} ? (
      [ $self->format_keyword('on') ],
      [ $self->render_aqt($args->{on}) ],
    ) : ()),
    ($args->{using} ? (
      [ $self->format_keyword('using') ],
      [ $self->render_aqt($args->{using}) ],
    ) : ()),
  );
  return $self->join_query_parts(' ', @parts);
}

sub _expand_op_as {
  my ($self, undef, $vv, $k) = @_;
  my @as = map $self->expand_expr($_, -ident),
             (defined($k) ? ($k) : ()), ref($vv) eq 'ARRAY' ? @$vv : $vv;
  return { -as => \@as };
}

sub _render_as {
  my ($self, undef, $args) = @_;
  my ($thing, @alias) = @$args;
  return $self->join_query_parts(
    ' ',
    [ $self->render_aqt($thing) ],
    [ $self->format_keyword('as') ],
    [ $self->_render_alias(\@alias) ],
  );
}

sub _render_alias {
  my ($self, $args) = @_;
  my ($as, @cols) = @$args;
  return (@cols
    ? $self->join_query_parts('',
         [ $self->render_aqt($as) ],
         [ '(' ],
         [ $self->join_query_parts(
             ', ',
             map [ $self->render_aqt($_) ], @cols
         ) ],
         [ ')' ],
      )
    : $self->render_aqt($as)
  );
}

sub _expand_update_clause_target {
  my ($self, undef, $target) = @_;
  +(target => $self->_expand_from_list(undef, $target));
}

1;
