package SQL::Abstract::ExtraClauses;

use Moo;

has sqla => (
  is => 'ro', init_arg => undef,
  handles => [ qw(
    expand_expr expand_maybe_list_expr render_aqt join_query_parts
  ) ],
);

sub cb {
  my ($self, $method, @args) = @_;
  return sub {
    local $self->{sqla} = shift;
    $self->$method(@args, @_)
  };
}

sub register {
  my ($self, @pairs) = @_;
  my $sqla = $self->sqla;
  while (my ($method, $cases) = splice(@pairs, 0, 2)) {
    my @cases = @$cases;
    while (my ($name, $case) = splice(@cases, 0, 2)) {
      $sqla->$method($name, $self->cb($case));
    }
  }
  return $self;
}

sub apply_to {
  my ($self, $sqla) = @_;
  $self = $self->new unless ref($self);
  local $self->{sqla} = $sqla;
  $self->register_extensions($sqla);
}

sub register_extensions {
  my ($self, $sqla) = @_;

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
  $sqla->clauses_of(select => @clauses);

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

  $self->register(
    (map +(
      "${_}er" => [
        do {
          my $x = $_;
          (map +($_ => "_${x}_${_}"), qw(join from_list alias))
        }
       ]
    ), qw(expand render)),
    binop_expander => [ as => '_expand_op_as' ],
    renderer => [ as => '_render_as' ],
    expander => [ cast => '_expand_cast' ],
    clause_expanders => [
      "select.from", '_expand_from_list',
      'select.group_by'
        => sub { $_[0]->expand_maybe_list_expr($_[2], -ident) },
      'select.having'
        => sub { $_[0]->expand_expr($_[2]) },
      'update.from' => '_expand_from_list',
      "update.target", '_expand_update_clause_target',
      "update.update", '_expand_update_clause_target',
      'delete.using' => '_expand_from_list',
      'insert.rowvalues' => sub {
        +(from => $_[0]->expand_expr({ -values => $_[2] }));
      },
      'insert.select' => sub {
        +(from => $_[0]->expand_expr({ -select => $_[2] }));
      },
    ],
  );

  # set ops
  $sqla->wrap_expander(select => sub {
    $self->cb('_expand_select', $_[0], \@before_setop);
  });

  $self->register(
    clause_renderer => [
      'select.setop' => sub { $_[0]->render_aqt($_[2]) }
    ],
    expander => [ map +($_ => '_expand_setop'), qw(union intersect except) ],
    renderer => [ map +($_ => '_render_setop'), qw(union intersect except) ],
  );

  my $setop_expander = $self->cb('_expand_clause_setop');

  $sqla->clause_expanders(
    map +($_ => $setop_expander),
      map "select.${_}",
        map +($_, "${_}_all", "${_}_distinct"),
          qw(union intersect except)
  );

  foreach my $stmt (qw(select insert update delete)) {
    $sqla->clauses_of($stmt => 'with', $sqla->clauses_of($stmt));
    $self->register(
      clause_expanders => [
        "${stmt}.with" => '_expand_with',
        "${stmt}.with_recursive" => '_expand_with',
      ],
      clause_renderer => [ "${stmt}.with" => '_render_with' ],
    );
  }

  return $sqla;
}

sub _expand_select {
  my ($self, $orig, $before_setop, @args) = @_;
  my $exp = $self->sqla->$orig(@args);
  return $exp unless my $setop = (my $sel = $exp->{-select})->{setop};
  if (my @keys = grep $sel->{$_}, @$before_setop) {
    my %inner; @inner{@keys} = delete @{$sel}{@keys};
    unshift @{(values(%$setop))[0]{queries}},
      { -select => \%inner };
  }
  return $exp;
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
    { -keyword => join '_', ($args->{type}||()), 'join' },
    (map +($_->{-ident} || $_->{-as} ? $_ : ('(', $_, ')')), $args->{to}),
    ($args->{on} ? (
      { -keyword => 'on' },
      $args->{on},
    ) : ()),
    ($args->{using} ? (
      { -keyword => 'using' },
      '(', $args->{using}, ')',
    ) : ()),
  );
  return $self->join_query_parts(' ', @parts);
}

sub _expand_op_as {
  my ($self, undef, $vv, $k) = @_;
  my @vv = (ref($vv) eq 'ARRAY' ? @$vv : $vv);
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
    { -keyword => 'as' },
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

sub _expand_cast {
  my ($self, undef, $thing) = @_;
  return { -func => [ cast => $thing ] } if ref($thing) eq 'HASH';
  my ($cast, $to) = @{$thing};
  +{ -func => [ cast => { -as => [
    $self->expand_expr($cast),
    $self->expand_expr($to, -ident),
  ] } ] };
}

sub _expand_alias {
  my ($self, undef, $args) = @_;
  if (ref($args) eq 'HASH' and my $alias = $args->{-alias}) {
    $args = $alias;
  }
  +{ -alias => [
      map $self->expand_expr($_, -ident),
      ref($args) eq 'ARRAY' ? @{$args} : $args
    ]
  }
}

sub _expand_with {
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
}

sub _render_with {
  my ($self, undef, $with) = @_;
  my $q_part = $self->join_query_parts(', ',
    map {
      my ($alias, $query) = @$_;
      $self->join_query_parts(' ',
          $alias,
          { -keyword => 'as' },
          $query,
      )
    } @{$with->{queries}}
  );
  return $self->join_query_parts(' ',
    { -keyword => join '_', 'with', ($with->{type}||'') },
    $q_part,
  );
}

sub _expand_setop {
  my ($self, $setop, $args) = @_;
  +{ "-${setop}" => {
       %$args,
       queries => [ map $self->expand_expr($_), @{$args->{queries}} ],
  } };
}

sub _render_setop {
  my ($self, $setop, $args) = @_;
  $self->join_query_parts(
    { -keyword => ' '.join('_', $setop, ($args->{type}||())).' ' },
    @{$args->{queries}}
  );
}

sub _expand_clause_setop {
  my ($self, $setop, $args) = @_;
  my ($op, $type) = split '_', $setop;
  +(setop => $self->expand_expr({
    "-${op}" => {
      ($type ? (type => $type) : ()),
      queries => (ref($args) eq 'ARRAY' ? $args : [ $args ])
    }
  }));
}

1;

__END__

=head1 NAME

SQL::Abstract::ExtraClauses - new/experimental additions to L<SQL::Abstract>

=head1 SYNOPSIS

  my $sqla = SQL::Abstract->new;
  SQL::Abstract::ExtraClauses->apply_to($sqla);

=head1 METHODS

=head2 apply_to

Applies the plugin to an L<SQL::Abstract> object.

=head2 register_extensions

Registers the extensions described below

=head2 cb

For plugin authors, creates a callback to call a method on the plugin.

=head2 register

For plugin authors, registers callbacks more easily.

=head2 sqla

Available only during plugin callback executions, contains the currently
active L<SQL::Abstract> object.

=head1 NODE TYPES

=head2 alias

Represents a table alias. Expands name and column names with ident as default.

  # expr
  { -alias => [ 't', 'x', 'y', 'z' ] }

  # aqt
  { -alias => [
      { -ident => [ 't' ] }, { -ident => [ 'x' ] },
      { -ident => [ 'y' ] }, { -ident => [ 'z' ] },
  ] }

  # query
  t(x, y, z)
  []

=head2 as

Represents an sql AS. LHS is expanded with ident as default, RHS is treated
as a list of arguments for the alias node.

  # expr
  { foo => { -as => 'bar' } }

  # aqt
  { -as =>
      [
        { -ident => [ 'foo' ] },
        { -alias => [ { -ident => [ 'bar' ] } ] },
      ]
  }

  # query
  foo AS bar
  []

  # expr
  { -as => [ { -select => { _ => 'blah' } }, 't', 'blah' ] }

  # aqt
  { -as => [
      { -select =>
          { select => { -op => [ ',', { -ident => [ 'blah' ] } ] } }
      },
      { -alias => [ { -ident => [ 't' ] }, { -ident => [ 'blah' ] } ] },
  ] }

  # query
  (SELECT blah) AS t(blah)
  []

=head2 cast

  # expr
  { -cast => [ { -ident => 'birthday' }, 'date' ] }

  # aqt
  { -func => [
      'cast', {
        -as => [ { -ident => [ 'birthday' ] }, { -ident => [ 'date' ] } ]
      },
  ] }

  # query
  CAST(birthday AS date)
  []

=cut
