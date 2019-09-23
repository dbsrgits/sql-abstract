package SQL::Abstract::ExtraClauses;

use Moo;

has sqla => (
  is => 'ro', init_arg => undef,
  handles => [ qw(
    expand_expr render_aqt
    format_keyword join_query_parts
  ) ],
);

BEGIN { *puke = \&SQL::Abstract::puke }

sub cb {
  my ($self, $method) = @_;
  return sub { local $self->{sqla} = shift; $self->$method(@_) };
}

sub apply_to {
  my ($self, $sqla) = @_;
  $self = $self->new unless ref($self);
  my @clauses = $sqla->clauses_of('select');
  my @before_setop;
  CLAUSE: foreach my $idx (0..$#clauses) {
    if ($clauses[$idx] eq 'order_by') {
      @before_setop = @clauses[0..$idx-1];
      splice(@clauses, $idx, 0, qw(setop group_by having));
      last CLAUSE;
    }
  }
  die "Huh?" unless @before_setop;
  $sqla->clauses_of(select => 'with', @clauses);
  $sqla->clause_expanders(
    'select.group_by', $self->cb(sub {
      $_[0]->sqla->_expand_maybe_list_expr($_[2], -ident)
    }),
    'select.having', $self->cb(sub { $_[0]->expand_expr($_[2]) }),
  );
  foreach my $thing (qw(join from_list)) {
    $sqla->expander($thing => $self->cb("_expand_${thing}"))
         ->renderer($thing => $self->cb("_render_${thing}"))
  }
  $sqla->op_expander(as => $self->cb('_expand_op_as'));
  $sqla->expander(as => $self->cb('_expand_op_as'));
  $sqla->renderer(as => $self->cb('_render_as'));
  $sqla->expander(alias => $self->cb(sub {
    my ($self, undef, $args) = @_;
    if (ref($args) eq 'HASH' and my $alias = $args->{-alias}) {
      $args = $alias;
    }
    +{ -alias => [
        map $self->expand_expr($_, -ident),
        ref($args) eq 'ARRAY' ? @{$args} : $args
      ]
    }
  }));
  $sqla->renderer(alias => $self->cb('_render_alias'));

  $sqla->clauses_of(update => sub {
    my ($self, @clauses) = @_;
    splice(@clauses, 2, 0, 'from');
    @clauses;
  });

  $sqla->clauses_of(delete => sub {
    my ($self, @clauses) = @_;
    splice(@clauses, 1, 0, 'using');
    @clauses;
  });

  $sqla->clause_expanders(
    'update.from' => $self->cb('_expand_select_clause_from'),
    'delete.using' => $self->cb(sub {
      +(using => $_[0]->_expand_from_list(undef, $_[2]));
    }),
    'insert.rowvalues' => $self->cb(sub {
      +(from => $_[0]->expand_expr({ -values => $_[2] }));
    }),
    'insert.select' => $self->cb(sub {
      +(from => $_[0]->expand_expr({ -select => $_[2] }));
    }),
  );

  # set ops
  $sqla->wrap_expander(select => sub {
    my $orig = shift;
    $self->cb(sub {
      my $self = shift;
      my $exp = $self->sqla->$orig(@_);
      return $exp unless my $setop = (my $sel = $exp->{-select})->{setop};
      if (my @keys = grep $sel->{$_}, @before_setop) {
        my %inner; @inner{@keys} = delete @{$sel}{@keys};
        unshift @{(values(%$setop))[0]{queries}},
          { -select => \%inner };
      }
      return $exp;
    });
  });
  my $expand_setop = $self->cb(sub {
    my ($self, $setop, $args) = @_;
    +{ "-${setop}" => {
         %$args,
         queries => [ map $self->expand_expr($_), @{$args->{queries}} ],
    } };
  });
  $sqla->expanders(map +($_ => $expand_setop), qw(union intersect except));

  $sqla->clause_renderer('select.setop' => $self->cb(sub {
    my ($self, undef, $setop) = @_;
    $self->render_aqt($setop);
  }));

  $sqla->renderer($_ => $self->cb(sub {
    my ($self, $setop, $args) = @_;
    $self->join_query_parts(
      ' '.$self->format_keyword(join '_', $setop, ($args->{type}||())).' ',
      @{$args->{queries}}
    );
  })) for qw(union intersect except);

  my $setop_expander = $self->cb(sub {
    my ($self, $setop, $args) = @_;
    my ($op, $type) = split '_', $setop;
    +(setop => $self->expand_expr({
      "-${op}" => {
        ($type ? (type => $type) : ()),
        queries => (ref($args) eq 'ARRAY' ? $args : [ $args ])
      }
    }));
  });

  $sqla->clause_expanders(
    map +($_ => $setop_expander),
      map "select.${_}",
        map +($_, "${_}_all", "${_}_distinct"),
          qw(union intersect except)
  );

  $sqla->clause_expander('select.with' => my $with_expander = $self->cb(sub {
    my ($self, $name, $with) = @_;
    my (undef, $type) = split '_', $name;
    if (ref($with) eq 'HASH') {
      return +{
        %$with,
        queries => [
          map +[
            $self->expand_expr({ -alias => $_->[0] }, -ident),
            $self->expand_expr($_->[1]),
          ], @{$with->{queries}}
        ]
      }
    }
    my @with = @$with;
    my @exp;
    while (my ($alias, $query) = splice @with, 0, 2) {
      push @exp, [
        $self->expand_expr({ -alias => $alias }, -ident),
        $self->expand_expr($query)
      ];
    }
    return +(with => { ($type ? (type => $type) : ()), queries => \@exp });
  }));
  $sqla->clause_expander('select.with_recursive', $with_expander);
  $sqla->clause_renderer('select.with' => my $with_renderer = $self->cb(sub {
    my ($self, undef, $with) = @_;
    my $q_part = $self->join_query_parts(', ',
      map {
        my ($alias, $query) = @$_;
        $self->join_query_parts(' ',
            $alias,
            $self->format_keyword('as'),
            $query,
        )
      } @{$with->{queries}}
    );
    return $self->join_query_parts(' ',
      $self->format_keyword(join '_', 'with', ($with->{type}||'')),
      $q_part,
    );
  }));
  foreach my $stmt (qw(insert update delete)) {
    $sqla->clauses_of($stmt => 'with', $sqla->clauses_of($stmt));
    $sqla->clause_expander("${stmt}.$_", $with_expander)
      for qw(with with_recursive);
    $sqla->clause_renderer("${stmt}.with", $with_renderer);
  }
  $sqla->expander(cast => $self->cb(sub {
    return { -func => [ cast => $_[2] ] } if ref($_[2]) eq 'HASH';
    my ($cast, $to) = @{$_[2]};
    +{ -func => [ cast => { -as => [
      $self->expand_expr($cast),
      $self->expand_expr($to, -ident),
    ] } ] };
  }));

  $sqla->clause_expanders(
    "select.from", $self->cb('_expand_select_clause_from'),
    "update.target", $self->cb('_expand_update_clause_target'),
    "update.update", $self->cb('_expand_update_clause_target'),
  );

  return $sqla;
}

sub _expand_select_clause_from {
  my ($self, undef, $from) = @_;
  +(from => $self->_expand_from_list(undef, $from));
}

sub _expand_from_list {
  my ($self, undef, $args) = @_;
  if (ref($args) eq 'HASH') {
    return $args if $args->{-from_list};
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
    $proto{to} = $self->expand_expr({ -as => [ $proto{to}, $as ] });
  }
  if (defined($proto{using}) and ref(my $using = $proto{using}) ne 'HASH') {
    $proto{using} = [
      map [ $self->expand_expr($_, -ident) ],
        ref($using) eq 'ARRAY' ? @$using: $using
    ];
  }
  my %ret = map +($_ => $self->expand_expr($proto{$_}, -ident)),
              sort keys %proto;
  return +{ -join => \%ret };
}

sub _render_from_list {
  my ($self, undef, $list) = @_;
  return $self->join_query_parts(', ', @$list);
}

sub _render_join {
  my ($self, undef, $args) = @_;

  my @parts = (
    $args->{from},
    $self->format_keyword(join '_', ($args->{type}||()), 'join'),
    (map +($_->{-ident} || $_->{-as} ? $_ : ('(', $_, ')')), $args->{to}),
    ($args->{on} ? (
      $self->format_keyword('on') ,
      $args->{on},
    ) : ()),
    ($args->{using} ? (
      $self->format_keyword('using'),
      '(', $args->{using}, ')',
    ) : ()),
  );
  return $self->join_query_parts(' ', @parts);
}

sub _expand_op_as {
  my ($self, undef, $vv, $k) = @_;
  my @vv = (ref($vv) eq 'ARRAY' ? @$vv : $vv);
  $k ||= shift @vv;
  my $ik = $self->expand_expr($k, -ident);
  return +{ -as => [ $ik, $self->expand_expr($vv[0], -alias) ] }
    if @vv == 1 and ref($vv[0]) eq 'HASH';

  my @as = map $self->expand_expr($_, -ident), @vv;
  return { -as => [ $ik, { -alias => \@as } ] };
}

sub _render_as {
  my ($self, undef, $args) = @_;
  my ($thing, $alias) = @$args;
  return $self->join_query_parts(
    ' ',
    $thing,
    $self->format_keyword('as'),
    $alias,
  );
}

sub _render_alias {
  my ($self, undef, $args) = @_;
  my ($as, @cols) = @$args;
  return (@cols
    ? $self->join_query_parts('',
         $as,
         '(',
         $self->join_query_parts(
           ', ',
           @cols
         ),
         ')',
      )
    : $self->render_aqt($as)
  );
}

sub _expand_update_clause_target {
  my ($self, undef, $target) = @_;
  +(target => $self->_expand_from_list(undef, $target));
}

1;
