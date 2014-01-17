package SQL::Abstract::Converter;

use Carp ();
use List::Util ();
use Scalar::Util ();
use Data::Query::ExprHelpers;
use Moo;
use namespace::clean;

has renderer_will_quote => (
  is => 'ro'
);

has lower_case => (
  is => 'ro'
);

has default_logic => (
  is => 'ro', coerce => sub { uc($_[0]) }, default => sub { 'OR' }
);

has bind_meta => (
  is => 'ro', default => sub { 1 }
);

has cmp => (is => 'ro', default => sub { '=' });

has sqltrue => (is => 'ro', default => sub { '1=1' });
has sqlfalse => (is => 'ro', default => sub { '0=1' });

has special_ops => (is => 'ro', default => sub { [] });

# XXX documented but I don't current fail any tests not using it
has unary_ops => (is => 'ro', default => sub { [] });

has injection_guard => (
  is => 'ro',
  default => sub {
    qr/
      \;
        |
      ^ \s* go \s
    /xmi;
  }
);

has identifier_sep => (
  is => 'ro', default => sub { '.' },
);

has always_quote => (is => 'ro', default => sub { 1 });

has convert => (is => 'ro');

has array_datatypes => (is => 'ro');

has equality_op => (
  is => 'ro',
  default => sub { qr/^ (?: = ) $/ix },
);

has inequality_op => (
  is => 'ro',
  default => sub { qr/^ (?: != | <> ) $/ix },
);

has like_op => (
  is => 'ro',
  default => sub { qr/^ (?: is \s+ )? r?like $/xi },
);

has not_like_op => (
  is => 'ro',
  default => sub { qr/^ (?: is \s+ )? not \s+ r?like $/xi },
);


sub _literal_to_dq {
  my ($self, $literal) = @_;
  my @bind;
  ($literal, @bind) = @$literal if ref($literal) eq 'ARRAY';
  Literal('SQL', $literal, [ $self->_bind_to_dq(@bind) ]);
}

sub _bind_to_dq {
  my ($self, @bind) = @_;
  return unless @bind;
  $self->bind_meta
    ? do {
        $self->_assert_bindval_matches_bindtype(@bind);
        map perl_scalar_value(reverse @$_), @bind
      }
    : map perl_scalar_value($_), @bind
}

sub _value_to_dq {
  my ($self, $value) = @_;
  $self->_maybe_convert_dq(perl_scalar_value($value, our $Cur_Col_Meta));
}

sub _ident_to_dq {
  my ($self, $ident) = @_;
  $self->_assert_pass_injection_guard($ident)
    unless $self->renderer_will_quote;
  $self->_maybe_convert_dq(
    Identifier(do {
      if (my $sep = $self->identifier_sep) {
        split /\Q$sep/, $ident
      } else {
        $ident
      }
    })
  );
}

sub _maybe_convert_dq {
  my ($self, $dq) = @_;
  if (my $c = $self->{where_convert}) {
    Operator({ 'SQL.Naive' => 'apply' }, [
        Identifier($self->_sqlcase($c)),
        $dq
      ]
    );
  } else {
    $dq;
  }
}

sub _op_to_dq {
  my ($self, $op, @args) = @_;
  $self->_assert_pass_injection_guard($op);
  Operator({ 'SQL.Naive' => $op }, \@args);
}

sub _assert_pass_injection_guard {
  if ($_[1] =~ $_[0]->{injection_guard}) {
    my $class = ref $_[0];
    die "Possible SQL injection attempt '$_[1]'. If this is indeed a part of the "
     . "desired SQL use literal SQL ( \'...' or \[ '...' ] ) or supply your own "
     . "{injection_guard} attribute to ${class}->new()"
  }
}

sub _insert_to_dq {
  my ($self, $table, $data, $options) = @_;
  my (@names, @values);
  if (ref($data) eq 'HASH') {
    @names = sort keys %$data;
    foreach my $k (@names) {
      local our $Cur_Col_Meta = $k;
      push @values, $self->_mutation_rhs_to_dq($data->{$k});
    }
  } elsif (ref($data) eq 'ARRAY') {
    local our $Cur_Col_Meta;
    @values = map $self->_mutation_rhs_to_dq($_), @$data;
  } else {
    die "Not handled yet";
  }
  my $returning;
  if (my $r_source = $options->{returning}) {
    $returning = [
      map +(ref($_) ? $self->_expr_to_dq($_) : $self->_ident_to_dq($_)),
        (ref($r_source) eq 'ARRAY' ? @$r_source : $r_source),
    ];
  }
  Insert(
    (@names ? ([ map $self->_ident_to_dq($_), @names ]) : undef),
    [ \@values ],
    $self->_table_to_dq($table),
    ($returning ? ($returning) : undef),
  );
}

sub _mutation_rhs_to_dq {
  my ($self, $v) = @_;
  if (ref($v) eq 'ARRAY') {
    if ($self->{array_datatypes}) {
      return $self->_value_to_dq($v);
    }
    $v = \do { my $x = $v };
  }
  if (ref($v) eq 'HASH') {
    my ($op, $arg, @rest) = %$v;

    die 'Operator calls in update/insert must be in the form { -op => $arg }'
      if (@rest or not $op =~ /^\-/);
  }
  return $self->_expr_to_dq($v);
}

sub _update_to_dq {
  my ($self, $table, $data, $where) = @_;

  die "Unsupported data type specified to \$sql->update"
    unless ref $data eq 'HASH';

  my @set;

  foreach my $k (sort keys %$data) {
    my $v = $data->{$k};
    local our $Cur_Col_Meta = $k;
    push @set, [ $self->_ident_to_dq($k), $self->_mutation_rhs_to_dq($v) ];
  }

  Update(
    \@set,
    $self->_where_to_dq($where),
    $self->_table_to_dq($table),
  );
}

sub _source_to_dq {
  my ($self, $table, undef, $where) = @_;

  my $source_dq = $self->_table_to_dq($table);

  if (my $where_dq = $self->_where_to_dq($where)) {
    $source_dq = Where($where_dq, $source_dq);
  }

  $source_dq;
}

sub _select_to_dq {
  my $self = shift;
  my ($table, $fields, $where, $order) = @_;

  my $source_dq = $self->_source_to_dq(@_);

  my $ordered_dq = do {
    if ($order) {
      $self->_order_by_to_dq($order, undef, undef, $source_dq);
    } else {
      $source_dq
    }
  };

  return $self->_select_select_to_dq($fields, $ordered_dq);
}

sub _select_select_to_dq {
  my ($self, $fields, $from_dq) = @_;

  $fields ||= '*';

  Select(
    $self->_select_field_list_to_dq($fields),
    $from_dq,
  );
}

sub _select_field_list_to_dq {
  my ($self, $fields) = @_;
  [ map $self->_select_field_to_dq($_),
      ref($fields) eq 'ARRAY' ? @$fields : $fields ];
}

sub _select_field_to_dq {
  my ($self, $field) = @_;
  if (my $ref = ref($field)) {
    if ($ref eq 'REF' and ref($$field) eq 'HASH') {
      return $$field;
    } else {
      return $self->_literal_to_dq($$field);
    }
  }
  return $self->_ident_to_dq($field)
}

sub _delete_to_dq {
  my ($self, $table, $where) = @_;
  Delete(
    $self->_where_to_dq($where),
    $self->_table_to_dq($table),
  );
}

sub _where_to_dq {
  my ($self, $where, $logic) = @_;

  return undef unless defined($where);

  # if we're given a simple string assume it's a literal
  return $self->_literal_to_dq($where) if !ref($where);

  # turn the convert misfeature on - only used in WHERE clauses
  local $self->{where_convert} = $self->convert;

  return $self->_expr_to_dq($where, $logic);
}

my %op_conversions = (
  '==' => '=',
  'eq' => '=',
  'ne' => '!=',
  '!' => 'NOT',
  'gt' => '>',
  'ge' => '>=',
  'lt' => '<',
  'le' => '<=',
  'defined' => 'IS NOT NULL',
);

sub _expr_to_dq {
  my ($self, $where, $logic) = @_;

  if (ref($where) eq 'ARRAY') {
    return $self->_expr_to_dq_ARRAYREF($where, $logic);
  } elsif (ref($where) eq 'HASH') {
    return $self->_expr_to_dq_HASHREF($where, $logic);
  } elsif (
    ref($where) eq 'SCALAR'
    or (ref($where) eq 'REF' and ref($$where) eq 'ARRAY')
  ) {
    return $self->_literal_to_dq($$where);
  } elsif (ref($where) eq 'REF' and ref($$where) eq 'HASH') {
    return map_dq_tree {
      if (
        is_Operator
        and not $_->{operator}{'SQL.Naive'}
        and my $op = $_->{operator}{'Perl'}
      ) {
        my $sql_op = $op_conversions{$op} || uc($op);
        return +{
          %{$_},
          operator => { 'SQL.Naive' => $sql_op }
        };
      }
      return $_;
    } $$where;
  } elsif (!ref($where) or Scalar::Util::blessed($where)) {
    return $self->_value_to_dq($where);
  }
  die "Can't handle $where";
}

sub _expr_to_dq_ARRAYREF {
  my ($self, $where, $logic) = @_;

  $logic = uc($logic || $self->default_logic || 'OR');
  $logic eq 'AND' or $logic eq 'OR' or die "unknown logic: $logic";

  return unless @$where;

  my ($first, @rest) = @$where;

  return $self->_expr_to_dq($first) unless @rest;

  my $first_dq = do {
    if (!ref($first)) {
      $self->_where_hashpair_to_dq($first => shift(@rest));
    } else {
      $self->_expr_to_dq($first);
    }
  };

  return $self->_expr_to_dq_ARRAYREF(\@rest, $logic) unless $first_dq;

  $self->_op_to_dq(
    $logic, $first_dq, $self->_expr_to_dq_ARRAYREF(\@rest, $logic)
  );
}

sub _expr_to_dq_HASHREF {
  my ($self, $where, $logic) = @_;

  $logic = uc($logic) if $logic;

  my @dq = map {
    $self->_where_hashpair_to_dq($_ => $where->{$_}, $logic)
  } sort keys %$where;

  return $dq[0] unless @dq > 1;

  my $final = pop(@dq);

  foreach my $dq (reverse @dq) {
    $final = $self->_op_to_dq($logic||'AND', $dq, $final);
  }

  return $final;
}

sub _where_to_dq_SCALAR {
  shift->_value_to_dq(@_);
}

sub _apply_to_dq {
  my ($self, $op, $v) = @_;
  my @args = map $self->_expr_to_dq($_), (ref($v) eq 'ARRAY' ? @$v : $v);

  # Ok. Welcome to stupid compat code land. An SQLA expr that would in the
  # absence of this piece of crazy render to:
  #
  #   A( B( C( x ) ) )
  #
  # such as
  #
  #   { -a => { -b => { -c => $x } } }
  #
  # actually needs to render to:
  #
  #   A( B( C x ) )
  #
  # because SQL sucks, and databases are hateful, and SQLA is Just That DWIM.
  #
  # However, we don't want to catch 'A(x)' and turn it into 'A x'
  #
  # So the way we deal with this is to go through all our arguments, and
  # then if the argument is -also- an apply, i.e. at least 'B', we check
  # its arguments - and if there's only one of them, and that isn't an apply,
  # then we convert to the bareword form. The end result should be:
  #
  # A( x )                   -> A( x )
  # A( B( x ) )              -> A( B x )
  # A( B( C( x ) ) )         -> A( B( C x ) )
  # A( B( x + y ) )          -> A( B( x + y ) )
  # A( B( x, y ) )           -> A( B( x, y ) )
  #
  # If this turns out not to be quite right, please add additional tests
  # to either 01generate.t or 02where.t *and* update this comment.

  foreach my $arg (@args) {
    if (
      is_Operator($arg) and $arg->{operator}{'SQL.Naive'} eq 'apply'
      and @{$arg->{args}} == 2 and !is_Operator($arg->{args}[1])

    ) {
      $arg->{operator}{'SQL.Naive'} = (shift @{$arg->{args}})->{elements}->[0];
    }
  }
  $self->_assert_pass_injection_guard($op);
  return $self->_op_to_dq(
    apply => $self->_ident_to_dq($op), @args
  );
}

sub _where_hashpair_to_dq {
  my ($self, $k, $v, $logic) = @_;

  if ($k =~ /^-(.*)/s) {
    my $op = uc($1);
    if ($op eq 'AND' or $op eq 'OR') {
      return $self->_expr_to_dq($v, $op);
    } elsif ($op eq 'NEST') {
      return $self->_expr_to_dq($v);
    } elsif ($op eq 'NOT') {
      return $self->_op_to_dq(NOT => $self->_expr_to_dq($v));
    } elsif ($op eq 'BOOL') {
      return ref($v) ? $self->_expr_to_dq($v) : $self->_ident_to_dq($v);
    } elsif ($op eq 'NOT_BOOL') {
      return $self->_op_to_dq(
        NOT => ref($v) ? $self->_expr_to_dq($v) : $self->_ident_to_dq($v)
      );
    } elsif ($op eq 'IDENT') {
      return $self->_ident_to_dq($v);
    } elsif ($op eq 'VALUE') {
      return $self->_value_to_dq($v);
    } elsif ($op =~ /^(?:AND|OR|NEST)_?\d+/) {
      die "Use of [and|or|nest]_N modifiers is no longer supported";
    } else {
      return $self->_apply_to_dq($op, $v);
    }
  } else {
    local our $Cur_Col_Meta = $k;
    if (ref($v) eq 'ARRAY') {
      if (!@$v) {
        return $self->_literal_to_dq($self->{sqlfalse});
      } elsif (defined($v->[0]) && $v->[0] =~ /-(and|or)/i) {
        return $self->_expr_to_dq_ARRAYREF([
          map +{ $k => $_ }, @{$v}[1..$#$v]
        ], uc($1));
      }
      return $self->_expr_to_dq_ARRAYREF([
        map +{ $k => $_ }, @$v
      ], $logic);
    } elsif (ref($v) eq 'SCALAR' or (ref($v) eq 'REF' and ref($$v) eq 'ARRAY')) {
      return Literal('SQL', [ $self->_ident_to_dq($k), $self->_literal_to_dq($$v) ]);
    }
    my ($op, $rhs) = do {
      if (ref($v) eq 'HASH') {
        if (keys %$v > 1) {
          return $self->_expr_to_dq_ARRAYREF([
            map +{ $k => { $_ => $v->{$_} } }, sort keys %$v
          ], $logic||'AND');
        }
        my ($op, $value) = %$v;
        s/^-//, s/_/ /g for $op;
        if ($op =~ /^(?:and|or)$/i) {
          return $self->_expr_to_dq({ $k => $value }, $op);
        } elsif (
          my $special_op = List::Util::first {$op =~ $_->{regex}}
                             @{$self->{special_ops}}
        ) {
          return $self->_literal_to_dq(
            [ $special_op->{handler}->($k, $op, $value) ]
          );
        } elsif ($op =~ /^(?:AND|OR|NEST)_?\d+$/i) {
          die "Use of [and|or|nest]_N modifiers is no longer supported";
        }
        (uc($op), $value);
      } else {
        ($self->{cmp}, $v);
      }
    };
    if ($op eq 'BETWEEN' or $op eq 'IN' or $op eq 'NOT IN' or $op eq 'NOT BETWEEN') {
      die "Argument passed to the '$op' operator can not be undefined" unless defined $rhs;
      $rhs = [$rhs] unless ref $rhs;
      if (ref($rhs) ne 'ARRAY') {
        if ($op =~ /^(?:NOT )?IN$/) {
          # have to add parens if none present because -in => \"SELECT ..."
          # got documented. mst hates everything.
          if (ref($rhs) eq 'SCALAR') {
            my $x = $$rhs;
            1 while ($x =~ s/\A\s*\((.*)\)\s*\Z/$1/s);
            $rhs = \$x;
          } elsif (ref($rhs) eq 'REF') {
            if (ref($$rhs) eq 'ARRAY') {
              my ($x, @rest) = @{$$rhs};
              1 while ($x =~ s/\A\s*\((.*)\)\s*\Z/$1/s);
              $rhs = \[ $x, @rest ];
            } elsif (ref($$rhs) eq 'HASH') {
              return $self->_op_to_dq($op, $self->_ident_to_dq($k), $$rhs);
            }
          }
        }
        return $self->_op_to_dq(
          $op, $self->_ident_to_dq($k), $self->_literal_to_dq($$rhs)
        );
      }
      die "Operator '$op' requires either an arrayref with two defined values or expressions, or a single literal scalarref/arrayref-ref"
        if $op =~ /^(?:NOT )?BETWEEN$/ and (@$rhs != 2 or grep !defined, @$rhs);
      if (grep !defined, @$rhs) {
        my ($inop, $logic, $nullop) = $op =~ /^NOT/
          ? (-not_in => AND => { '!=' => undef })
          : (-in => OR => undef);
        if (my @defined = grep defined, @$rhs) {
          return $self->_expr_to_dq_ARRAYREF([
            { $k => { $inop => \@defined } },
            { $k => $nullop },
          ], $logic);
        }
        return $self->_expr_to_dq_HASHREF({ $k => $nullop });
      }
      return $self->_literal_to_dq(
        $op =~ /^NOT/ ? $self->{sqltrue} : $self->{sqlfalse}
      ) unless @$rhs;
      return $self->_op_to_dq(
        $op, $self->_ident_to_dq($k), map $self->_expr_to_dq($_), @$rhs
      )
    } elsif ($op =~ s/^NOT (?!R?LIKE)//) {
      return $self->_where_hashpair_to_dq(-not => { $k => { $op => $rhs } });
    } elsif ($op eq 'IDENT') {
      return $self->_op_to_dq(
        $self->{cmp}, $self->_ident_to_dq($k), $self->_ident_to_dq($rhs)
      );
    } elsif ($op eq 'VALUE') {
      return $self->_op_to_dq(
        $self->{cmp}, $self->_ident_to_dq($k), $self->_value_to_dq($rhs)
      );
    } elsif (!defined($rhs)) {
      my $null_op = do {
        warn "Supplying an undefined argument to '$op' is deprecated"
          if $op =~ $self->like_op or $op =~ $self->not_like_op;
        if ($op =~ $self->equality_op or $op =~ $self->like_op or $op eq 'IS') {
          'IS NULL'
        } elsif (
          $op =~ $self->inequality_op or $op =~ $self->not_like_op
            or
          $op eq 'IS NOT' or $op eq 'NOT'
        ) {
          'IS NOT NULL'
        } else {
          die "Can't do undef -> NULL transform for operator ${op}";
        }
      };
      return $self->_op_to_dq($null_op, $self->_ident_to_dq($k));
    }
    if (ref($rhs) eq 'ARRAY') {
      if (!@$rhs) {
        if ($op =~ $self->like_op or $op =~ $self->not_like_op) {
          warn "Supplying an empty arrayref to '$op' is deprecated";
        } elsif ($op !~ $self->equality_op and $op !~ $self->inequality_op) {
          die "operator '$op' applied on an empty array (field '$k')";
        }
        return $self->_literal_to_dq(
          ($op =~ $self->inequality_op or $op =~ $self->not_like_op)
            ? $self->{sqltrue} : $self->{sqlfalse}
        );
      } elsif (defined($rhs->[0]) and $rhs->[0] =~ /^-(and|or)$/i) {
        return $self->_expr_to_dq_ARRAYREF([
          map +{ $k => { $op => $_ } }, @{$rhs}[1..$#$rhs]
        ], uc($1));
      } elsif ($op =~ /^-(?:AND|OR|NEST)_?\d+/) {
        die "Use of [and|or|nest]_N modifiers is no longer supported";
      } elsif (@$rhs > 1 and ($op =~ $self->inequality_op or $op =~ $self->not_like_op)) {
        warn "A multi-element arrayref as an argument to the inequality op '$op' "
          . 'is technically equivalent to an always-true 1=1 (you probably wanted '
          . "to say ...{ \$inequality_op => [ -and => \@values ] }... instead)";
      }
      return $self->_expr_to_dq_ARRAYREF([
        map +{ $k => { $op => $_ } }, @$rhs
      ]);
    }
    return $self->_op_to_dq(
      $op, $self->_ident_to_dq($k), $self->_expr_to_dq($rhs)
    );
  }
}

sub _order_by_to_dq {
  my ($self, $arg, $dir, $nulls, $from) = @_;

  return unless $arg;

  my $dq = Order(
    undef,
    (defined($dir) ? (!!($dir =~ /desc/i)) : undef),
    $nulls,
    ($from ? ($from) : undef),
  );

  if (!ref($arg)) {
    $dq->{by} = $self->_ident_to_dq($arg);
  } elsif (ref($arg) eq 'ARRAY') {
    return unless @$arg;
    local our $Order_Inner unless our $Order_Recursing;
    local $Order_Recursing = 1;
    my ($outer, $inner);
    foreach my $member (@$arg) {
      local $Order_Inner;
      my $next = $self->_order_by_to_dq($member, $dir, $nulls, $from);
      $outer ||= $next;
      $inner->{from} = $next if $inner;
      $inner = $Order_Inner || $next;
    }
    $Order_Inner = $inner;
    return $outer;
  } elsif (ref($arg) eq 'REF' and ref($$arg) eq 'ARRAY') {
    $dq->{by} = $self->_literal_to_dq($$arg);
  } elsif (ref($arg) eq 'REF' and ref($$arg) eq 'HASH') {
    $dq->{by} = $$arg;
  } elsif (ref($arg) eq 'SCALAR') {

    # < mst> right, but if it doesn't match that, it goes "ok, right, not sure,
    #        totally leaving this untouched as a literal"
    # < mst> so I -think- it's relatively robust
    # < ribasushi> right, it's relatively safe then
    # < ribasushi> is this regex centralized?
    # < mst> it only exists in _order_by_to_dq in SQL::Abstract::Converter
    # < mst> it only exists because you were kind enough to support new
    #        dbihacks crack combined with old literal order_by crack
    # < ribasushi> heh :)

    # this should take into account our quote char and name sep

    my $match_ident = '\w+(?:\.\w+)*';

    if (my ($ident, $dir) = $$arg =~ /^(${match_ident})(?:\s+(desc|asc))?$/i) {
      $dq->{by} = $self->_ident_to_dq($ident);
      $dq->{reverse} = 1 if $dir and lc($dir) eq 'desc';
    } else {
      $dq->{by} = $self->_literal_to_dq($$arg);
    }
  } elsif (ref($arg) eq 'HASH') {
    return () unless %$arg;

    my ($direction, $val);
    foreach my $key (keys %$arg) {
      if ( $key =~ /^-(desc|asc)/i ) {
        die "hash passed to _order_by_to_dq must have exactly one of -desc or -asc"
            if defined $direction;
        $direction = $1;
        $val = $arg->{$key};
      } elsif ($key =~ /^-nulls$/i)  {
        $nulls = $arg->{$key};
        die "invalid value for -nulls" unless $nulls =~ /^(?:first|last|none)$/i;
      } else {
        die "invalid key ${key} in hash passed to _order_by_to_dq";
      }
    }

    die "hash passed to _order_by_to_dq must have exactly one of -desc or -asc"
        unless defined $direction;

    return $self->_order_by_to_dq($val, $direction, $nulls, $from);
  } else {
    die "Can't handle $arg in _order_by_to_dq";
  }
  return $dq;
}

sub _table_to_dq {
  my ($self, $from) = @_;
  if (ref($from) eq 'ARRAY') {
    die "Empty FROM list" unless my @f = @$from;
    my $dq = $self->_table_to_dq(shift @f);
    while (my $x = shift @f) {
      $dq = Join(
        $dq,
        $self->_table_to_dq($x),
      );
    }
    $dq;
  } elsif (ref($from) eq 'SCALAR' or (ref($from) eq 'REF')) {
    $self->_literal_to_dq($$from);
  } else {
    $self->_ident_to_dq($from);
  }
}

# And bindtype
sub _bindtype (@) {
  #my ($self, $col, @vals) = @_;

  #LDNOTE : changed original implementation below because it did not make
  # sense when bindtype eq 'columns' and @vals > 1.
#  return $self->{bindtype} eq 'columns' ? [ $col, @vals ] : @vals;

  # called often - tighten code
  return $_[0]->bind_meta
    ? map {[$_[1], $_]} @_[2 .. $#_]
    : @_[2 .. $#_]
  ;
}

# Dies if any element of @bind is not in [colname => value] format
# if bindtype is 'columns'.
sub _assert_bindval_matches_bindtype {
#  my ($self, @bind) = @_;
  my $self = shift;
  if ($self->bind_meta) {
    for (@_) {
      if (!defined $_ || ref($_) ne 'ARRAY' || @$_ != 2) {
        die "bindtype 'columns' selected, you need to pass: [column_name => bind_value]"
      }
    }
  }
}

# Fix SQL case, if so requested
sub _sqlcase {
  return $_[0]->lower_case ? $_[1] : uc($_[1]);
}

1;
