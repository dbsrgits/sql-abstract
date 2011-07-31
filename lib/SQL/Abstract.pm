package SQL::Abstract; # see doc at end of file

# LDNOTE : this code is heavy refactoring from original SQLA.
# Several design decisions will need discussion during
# the test / diffusion / acceptance phase; those are marked with flag
# 'LDNOTE' (note by laurent.dami AT free.fr)

use strict;
use Carp ();
use warnings FATAL => 'all';
use List::Util ();
use Scalar::Util ();
use Data::Query::Constants qw(
  DQ_IDENTIFIER DQ_OPERATOR DQ_VALUE DQ_LITERAL DQ_JOIN DQ_SELECT DQ_ORDER
  DQ_WHERE DQ_DELETE DQ_UPDATE DQ_INSERT
);
use Data::Query::ExprHelpers qw(perl_scalar_value);

#======================================================================
# GLOBALS
#======================================================================

our $VERSION  = '1.72';

# This would confuse some packagers
$VERSION = eval $VERSION if $VERSION =~ /_/; # numify for warning-free dev releases

our $AUTOLOAD;

# special operators (-in, -between). May be extended/overridden by user.
# See section WHERE: BUILTIN SPECIAL OPERATORS below for implementation
my @BUILTIN_SPECIAL_OPS = ();

# unaryish operators - key maps to handler
my @BUILTIN_UNARY_OPS = ();

#======================================================================
# DEBUGGING AND ERROR REPORTING
#======================================================================

sub _debug {
  return unless $_[0]->{debug}; shift; # a little faster
  my $func = (caller(1))[3];
  warn "[$func] ", @_, "\n";
}

sub belch (@) {
  my($func) = (caller(1))[3];
  Carp::carp "[$func] Warning: ", @_;
}

sub puke (@) {
  my($func) = (caller(1))[3];
  Carp::croak "[$func] Fatal: ", @_;
}


#======================================================================
# NEW
#======================================================================

sub new {
  my $self = shift;
  my $class = ref($self) || $self;
  my %opt = (ref $_[0] eq 'HASH') ? %{$_[0]} : @_;

  # choose our case by keeping an option around
  delete $opt{case} if $opt{case} && $opt{case} ne 'lower';

  # default logic for interpreting arrayrefs
  $opt{logic} = $opt{logic} ? uc $opt{logic} : 'OR';

  # how to return bind vars
  # LDNOTE: changed nwiger code : why this 'delete' ??
  # $opt{bindtype} ||= delete($opt{bind_type}) || 'normal';
  $opt{bindtype} ||= 'normal';

  # default comparison is "=", but can be overridden
  $opt{cmp} ||= '=';

  # try to recognize which are the 'equality' and 'unequality' ops
  # (temporary quickfix, should go through a more seasoned API)
  $opt{equality_op}   = qr/^(\Q$opt{cmp}\E|is|(is\s+)?like)$/i;
  $opt{inequality_op} = qr/^(!=|<>|(is\s+)?not(\s+like)?)$/i;

  # SQL booleans
  $opt{sqltrue}  ||= '1=1';
  $opt{sqlfalse} ||= '0=1';

  # special operators
  $opt{special_ops} ||= [];
  # regexes are applied in order, thus push after user-defines
  push @{$opt{special_ops}}, @BUILTIN_SPECIAL_OPS;

  # unary operators
  $opt{unary_ops} ||= [];
  push @{$opt{unary_ops}}, @BUILTIN_UNARY_OPS;

  # rudimentary saniy-check for user supplied bits treated as functions/operators
  # If a purported  function matches this regular expression, an exception is thrown.
  # Literal SQL is *NOT* subject to this check, only functions (and column names
  # when quoting is not in effect)

  # FIXME
  # need to guard against ()'s in column names too, but this will break tons of
  # hacks... ideas anyone?
  $opt{injection_guard} ||= qr/
    \;
      |
    ^ \s* go \s
  /xmi;

  $opt{name_sep} ||= '.';

  $opt{renderer} ||= do {
    require Data::Query::Renderer::SQL::Naive;
    my ($always, $chars);
    for ($opt{quote_char}) {
      $chars = defined() ? (ref() ? $_ : [$_]) : ['',''];
      $always = defined;
    }
    Data::Query::Renderer::SQL::Naive->new({
      quote_chars => $chars, always_quote => $always,
      ($opt{case} ? (lc_keywords => 1) : ()), # always 'lower' if it exists
    });
  };

  return bless \%opt, $class;
}

sub _render_dq {
  my ($self, $dq) = @_;
  if (!$dq) {
    return '';
  }
  my ($sql, @bind) = @{$self->{renderer}->render($dq)};
  wantarray ?
    ($self->{bindtype} eq 'normal'
      ? ($sql, map $_->{value}, @bind)
      : ($sql, map [ $_->{value_meta}, $_->{value} ], @bind)
    )
    : $sql;
}

sub _literal_to_dq {
  my ($self, $literal) = @_;
  my @bind;
  ($literal, @bind) = @$literal if ref($literal) eq 'ARRAY';
  +{
    type => DQ_LITERAL,
    subtype => 'SQL',
    literal => $literal,
    (@bind ? (values => [ $self->_bind_to_dq(@bind) ]) : ()),
  };
}

sub _bind_to_dq {
  my ($self, @bind) = @_;
  return unless @bind;
  $self->{bindtype} eq 'normal'
    ? map perl_scalar_value($_), @bind
    : do {
        $self->_assert_bindval_matches_bindtype(@bind);
        map perl_scalar_value(reverse @$_), @bind
      }
}

sub _value_to_dq {
  my ($self, $value) = @_;
  $self->_maybe_convert_dq(perl_scalar_value($value, our $Cur_Col_Meta));
}

sub _ident_to_dq {
  my ($self, $ident) = @_;
  $self->_assert_pass_injection_guard($ident)
    unless $self->{renderer}{always_quote};
  $self->_maybe_convert_dq({
    type => DQ_IDENTIFIER,
    elements => [ split /\Q$self->{name_sep}/, $ident ],
  });
}

sub _maybe_convert_dq {
  my ($self, $dq) = @_;
  if (my $c = $self->{where_convert}) {
    +{
       type => DQ_OPERATOR,
       operator => { 'SQL.Naive' => 'apply' },
       args => [
         { type => DQ_IDENTIFIER, elements => [ $self->_sqlcase($c) ] },
         $dq
       ]
     };
  } else {
    $dq;
  }
}

sub _op_to_dq {
  my ($self, $op, @args) = @_;
  $self->_assert_pass_injection_guard($op);
  +{
    type => DQ_OPERATOR,
    operator => { 'SQL.Naive' => $op },
    args => \@args
  };
}

sub _assert_pass_injection_guard {
  if ($_[1] =~ $_[0]->{injection_guard}) {
    my $class = ref $_[0];
    puke "Possible SQL injection attempt '$_[1]'. If this is indeed a part of the "
     . "desired SQL use literal SQL ( \'...' or \[ '...' ] ) or supply your own "
     . "{injection_guard} attribute to ${class}->new()"
  }
}


#======================================================================
# INSERT methods
#======================================================================

sub insert {
  my $self = shift;
  $self->_render_dq($self->_insert_to_dq(@_));
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
  +{
    type => DQ_INSERT,
    target => $self->_ident_to_dq($table),
    (@names ? (names => [ map $self->_ident_to_dq($_), @names ]) : ()),
    values => [ \@values ],
    ($returning ? (returning => $returning) : ()),
  };
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

    puke 'Operator calls in update/insert must be in the form { -op => $arg }'
      if (@rest or not $op =~ /^\-(.+)/);
  }
  return $self->_expr_to_dq($v);
}

#======================================================================
# UPDATE methods
#======================================================================


sub update {
  my $self = shift;
  $self->_render_dq($self->_update_to_dq(@_));
}

sub _update_to_dq {
  my ($self, $table, $data, $where) = @_;

  puke "Unsupported data type specified to \$sql->update"
    unless ref $data eq 'HASH';

  my @set;

  foreach my $k (sort keys %$data) {
    my $v = $data->{$k};
    local our $Cur_Col_Meta = $k;
    push @set, [ $self->_ident_to_dq($k), $self->_mutation_rhs_to_dq($v) ];
  }

  return +{
    type => DQ_UPDATE,
    target => $self->_ident_to_dq($table),
    set => \@set,
    where => $self->_where_to_dq($where),
  };
}


#======================================================================
# SELECT
#======================================================================

sub _source_to_dq {
  my ($self, $table, $where) = @_;

  my $source_dq = $self->_table_to_dq($table);

  if (my $where_dq = $self->_where_to_dq($where)) {
    $source_dq = {
      type => DQ_WHERE,
      from => $source_dq,
      where => $where_dq,
    };
  }

  $source_dq;
}

sub select {
  my $self   = shift;
  return $self->_render_dq($self->_select_to_dq(@_));
}

sub _select_to_dq {
  my ($self, $table, $fields, $where, $order) = @_;
  $fields ||= '*';

  my $source_dq = $self->_source_to_dq($table, $where);

  my $final_dq = {
    type => DQ_SELECT,
    select => [
      map $self->_ident_to_dq($_),
        ref($fields) eq 'ARRAY' ? @$fields : $fields
    ],
    from => $source_dq,
  };

  if ($order) {
    $final_dq = $self->_order_by_to_dq($order, undef, $final_dq);
  }

  return $final_dq;
}

#======================================================================
# DELETE
#======================================================================


sub delete {
  my $self  = shift;
  $self->_render_dq($self->_delete_to_dq(@_));
}

sub _delete_to_dq {
  my ($self, $table, $where) = @_;
  +{
    type => DQ_DELETE,
    target => $self->_table_to_dq($table),
    where => $self->_where_to_dq($where),
  }
}


#======================================================================
# WHERE: entry point
#======================================================================



# Finally, a separate routine just to handle WHERE clauses
sub where {
  my ($self, $where, $order) = @_;

  my $sql = '';
  my @bind;

  # where ?
  ($sql, @bind) = $self->_recurse_where($where) if defined($where);
  $sql = $sql ? $self->_sqlcase(' where ') . "( $sql )" : '';

  # order by?
  if ($order) {
    $sql .= $self->_order_by($order);
  }

  return wantarray ? ($sql, @bind) : $sql;
}

sub _recurse_where {
  my ($self, $where, $logic) = @_;

  return $self->_render_dq($self->_where_to_dq($where, $logic));
}

sub _where_to_dq {
  my ($self, $where, $logic) = @_;

  return undef unless defined($where);

  # turn the convert misfeature on - only used in WHERE clauses
  local $self->{where_convert} = $self->{convert};

  return $self->_expr_to_dq($where, $logic);
}

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
  } elsif (!ref($where) or Scalar::Util::blessed($where)) {
    return $self->_value_to_dq($where);
  }
  die "Can't handle $where";
}

sub _expr_to_dq_ARRAYREF {
  my ($self, $where, $logic) = @_;

  $logic = uc($logic || $self->{logic} || 'OR');
  $logic eq 'AND' or $logic eq 'OR' or puke "unknown logic: $logic";

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

sub _where_op_IDENT {
  my $self = shift;
  my ($op, $rhs) = splice @_, -2;
  if (ref $rhs) {
    puke "-$op takes a single scalar argument (a quotable identifier)";
  }

  # in case we are called as a top level special op (no '=')
  my $lhs = shift;

  $_ = $self->_convert($self->_quote($_)) for ($lhs, $rhs);

  return $lhs
    ? "$lhs = $rhs"
    : $rhs
  ;
}

sub _where_op_VALUE {
  my $self = shift;
  my ($op, $rhs) = splice @_, -2;

  # in case we are called as a top level special op (no '=')
  my $lhs = shift;

  my @bind =
    $self->_bindtype (
      ($lhs || $self->{_nested_func_lhs}),
      $rhs,
    )
  ;

  return $lhs
    ? (
      $self->_convert($self->_quote($lhs)) . ' = ' . $self->_convert('?'),
      @bind
    )
    : (
      $self->_convert('?'),
      @bind,
    )
  ;
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
    } elsif ($op =~ /^(?:AND|OR|NEST)_?\d+/) {
      die "Use of [and|or|nest]_N modifiers is no longer supported";
    } else {
      my @args = do {
        if (ref($v) eq 'HASH' and keys(%$v) == 1 and (keys %$v)[0] =~ /^-(.*)/s) {
          my $op = uc($1);
          my ($inner) = values %$v;
          $self->_op_to_dq(
            $op,
            (map $self->_expr_to_dq($_),
              (ref($inner) eq 'ARRAY' ? @$inner : $inner))
          );
        } else {
          (map $self->_expr_to_dq($_), (ref($v) eq 'ARRAY' ? @$v : $v))
        }
      };
      $self->_assert_pass_injection_guard($op);
      return $self->_op_to_dq(
        apply => $self->_ident_to_dq($op), @args
      );
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
      return +{
        type => DQ_LITERAL,
        subtype => 'SQL',
        parts => [ $self->_ident_to_dq($k), $self->_literal_to_dq($$v) ]
      };
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
        if ($op =~ /^(and|or)$/i) {
          return $self->_expr_to_dq({ $k => $value }, $op);
        } elsif (
          my $special_op = List::Util::first {$op =~ $_->{regex}}
                             @{$self->{special_ops}}
        ) {
          return $self->_literal_to_dq(
            [ $self->${\$special_op->{handler}}($k, $op, $value) ]
          );;
        } elsif ($op =~ /^(?:AND|OR|NEST)_?\d+$/i) {
          die "Use of [and|or|nest]_N modifiers is no longer supported";
        }
        (uc($op), $value);
      } else {
        ($self->{cmp}, $v);
      }
    };
    if ($op eq 'BETWEEN' or $op eq 'IN' or $op eq 'NOT IN' or $op eq 'NOT BETWEEN') {
      if (ref($rhs) ne 'ARRAY') {
        if ($op =~ /IN$/) {
          # have to add parens if none present because -in => \"SELECT ..."
          # got documented. mst hates everything.
          if (ref($rhs) eq 'SCALAR') {
            my $x = $$rhs;
            1 while ($x =~ s/\A\s*\((.*)\)\s*\Z/$1/s);
            $rhs = \$x;
          } else {
            my ($x, @rest) = @{$$rhs};
            1 while ($x =~ s/\A\s*\((.*)\)\s*\Z/$1/s);
            $rhs = \[ $x, @rest ];
          }
        }
        return $self->_op_to_dq(
          $op, $self->_ident_to_dq($k), $self->_literal_to_dq($$rhs)
        );
      }
      return $self->_literal_to_dq($self->{sqlfalse}) unless @$rhs;
      return $self->_op_to_dq(
        $op, $self->_ident_to_dq($k), map $self->_expr_to_dq($_), @$rhs
      )
    } elsif ($op =~ s/^NOT (?!LIKE)//) {
      return $self->_where_hashpair_to_dq(-not => { $k => { $op => $rhs } });
    } elsif (!defined($rhs)) {
      my $null_op = do {
        if ($op eq '=' or $op eq 'LIKE') {
          'IS NULL'
        } elsif ($op eq '!=') {
          'IS NOT NULL'
        } else {
          die "Can't do undef -> NULL transform for operator ${op}";
        }
      };
      return $self->_op_to_dq($null_op, $self->_ident_to_dq($k));
    }
    if (ref($rhs) eq 'ARRAY') {
      if (!@$rhs) {
        return $self->_literal_to_dq(
          $op eq '!=' ? $self->{sqltrue} : $self->{sqlfalse}
        );
      } elsif (defined($rhs->[0]) and $rhs->[0] =~ /^-(and|or)$/i) {
        return $self->_expr_to_dq_ARRAYREF([
          map +{ $k => { $op => $_ } }, @{$rhs}[1..$#$rhs]
        ], uc($1));
      } elsif ($op =~ /^-(?:AND|OR|NEST)_?\d+/) {
        die "Use of [and|or|nest]_N modifiers is no longer supported";
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

#======================================================================
# ORDER BY
#======================================================================

sub _order_by {
  my ($self, $arg) = @_;
  if (my $dq = $self->_order_by_to_dq($arg)) {
    # SQLA generates ' ORDER BY foo'. The hilarity.
    wantarray
      ? do { my @r = $self->_render_dq($dq); $r[0] = ' '.$r[0]; @r }
      : ' '.$self->_render_dq($dq);
  } else {
    '';
  }
}

sub _order_by_to_dq {
  my ($self, $arg, $dir, $from) = @_;

  return unless $arg;

  my $dq = {
    type => DQ_ORDER,
    ($dir ? (direction => $dir) : ()),
    ($from ? (from => $from) : ()),
  };

  if (!ref($arg)) {
    $dq->{by} = $self->_ident_to_dq($arg);
  } elsif (ref($arg) eq 'ARRAY') {
    return unless @$arg;
    local our $Order_Inner unless our $Order_Recursing;
    local $Order_Recursing = 1;
    my ($outer, $inner);
    foreach my $member (@$arg) {
      local $Order_Inner;
      my $next = $self->_order_by_to_dq($member, $dir, $from);
      $outer ||= $next;
      $inner->{from} = $next if $inner;
      $inner = $Order_Inner || $next;
    }
    $Order_Inner = $inner;
    return $outer;
  } elsif (ref($arg) eq 'REF' and ref($$arg) eq 'ARRAY') {
    $dq->{by} = $self->_literal_to_dq($$arg);
  } elsif (ref($arg) eq 'SCALAR') {
    $dq->{by} = $self->_literal_to_dq($$arg);
  } elsif (ref($arg) eq 'HASH') {
    my ($key, $val, @rest) = %$arg;

    return unless $key;

    if (@rest or not $key =~ /^-(desc|asc)/i) {
      puke "hash passed to _order_by must have exactly one key (-desc or -asc)";
    }
    my $dir = uc $1;
    return $self->_order_by_to_dq($val, $dir, $from);
  } else {
    die "Can't handle $arg in _order_by_to_dq";
  }
  return $dq;
}

#======================================================================
# DATASOURCE (FOR NOW, JUST PLAIN TABLE OR LIST OF TABLES)
#======================================================================

sub _table  {
  my ($self, $from) = @_;
  $self->_render_dq($self->_table_to_dq($from));
}

sub _table_to_dq {
  my ($self, $from) = @_;
  if (ref($from) eq 'ARRAY') {
    die "Empty FROM list" unless my @f = @$from;
    my $dq = $self->_ident_to_dq(shift @f);
    while (my $x = shift @f) {
      $dq = {
        type => DQ_JOIN,
        join => [ $dq, $self->_ident_to_dq($x) ]
      };
    }
    $dq;
  } elsif (ref($from) eq 'SCALAR') {
    +{
      type => DQ_LITERAL,
      subtype => 'SQL',
      literal => $$from
    }
  } else {
    $self->_ident_to_dq($from);
  }
}


#======================================================================
# UTILITY FUNCTIONS
#======================================================================

# highly optimized, as it's called way too often
sub _quote {
  # my ($self, $label) = @_;

  return '' unless defined $_[1];
  return ${$_[1]} if ref($_[1]) eq 'SCALAR';

  unless ($_[0]->{quote_char}) {
    $_[0]->_assert_pass_injection_guard($_[1]);
    return $_[1];
  }

  my $qref = ref $_[0]->{quote_char};
  my ($l, $r);
  if (!$qref) {
    ($l, $r) = ( $_[0]->{quote_char}, $_[0]->{quote_char} );
  }
  elsif ($qref eq 'ARRAY') {
    ($l, $r) = @{$_[0]->{quote_char}};
  }
  else {
    puke "Unsupported quote_char format: $_[0]->{quote_char}";
  }

  # parts containing * are naturally unquoted
  return join( $_[0]->{name_sep}||'', map
    { $_ eq '*' ? $_ : $l . $_ . $r }
    ( $_[0]->{name_sep} ? split (/\Q$_[0]->{name_sep}\E/, $_[1] ) : $_[1] )
  );
}


# Conversion, if applicable
sub _convert ($) {
  #my ($self, $arg) = @_;

# LDNOTE : modified the previous implementation below because
# it was not consistent : the first "return" is always an array,
# the second "return" is context-dependent. Anyway, _convert
# seems always used with just a single argument, so make it a
# scalar function.
#     return @_ unless $self->{convert};
#     my $conv = $self->_sqlcase($self->{convert});
#     my @ret = map { $conv.'('.$_.')' } @_;
#     return wantarray ? @ret : $ret[0];
  if ($_[0]->{convert}) {
    return $_[0]->_sqlcase($_[0]->{convert}) .'(' . $_[1] . ')';
  }
  return $_[1];
}

# And bindtype
sub _bindtype (@) {
  #my ($self, $col, @vals) = @_;

  #LDNOTE : changed original implementation below because it did not make
  # sense when bindtype eq 'columns' and @vals > 1.
#  return $self->{bindtype} eq 'columns' ? [ $col, @vals ] : @vals;

  # called often - tighten code
  return $_[0]->{bindtype} eq 'columns'
    ? map {[$_[1], $_]} @_[2 .. $#_]
    : @_[2 .. $#_]
  ;
}

# Dies if any element of @bind is not in [colname => value] format
# if bindtype is 'columns'.
sub _assert_bindval_matches_bindtype {
#  my ($self, @bind) = @_;
  my $self = shift;
  if ($self->{bindtype} eq 'columns') {
    for (@_) {
      if (!defined $_ || ref($_) ne 'ARRAY' || @$_ != 2) {
        puke "bindtype 'columns' selected, you need to pass: [column_name => bind_value]"
      }
    }
  }
}

sub _join_sql_clauses {
  my ($self, $logic, $clauses_aref, $bind_aref) = @_;

  if (@$clauses_aref > 1) {
    my $join  = " " . $self->_sqlcase($logic) . " ";
    my $sql = '( ' . join($join, @$clauses_aref) . ' )';
    return ($sql, @$bind_aref);
  }
  elsif (@$clauses_aref) {
    return ($clauses_aref->[0], @$bind_aref); # no parentheses
  }
  else {
    return (); # if no SQL, ignore @$bind_aref
  }
}


# Fix SQL case, if so requested
sub _sqlcase {
  # LDNOTE: if $self->{case} is true, then it contains 'lower', so we
  # don't touch the argument ... crooked logic, but let's not change it!
  return $_[0]->{case} ? $_[1] : uc($_[1]);
}


#======================================================================
# DISPATCHING FROM REFKIND
#======================================================================

sub _refkind {
  my ($self, $data) = @_;

  return 'UNDEF' unless defined $data;

  # blessed objects are treated like scalars
  my $ref = (Scalar::Util::blessed $data) ? '' : ref $data;

  return 'SCALAR' unless $ref;

  my $n_steps = 1;
  while ($ref eq 'REF') {
    $data = $$data;
    $ref = (Scalar::Util::blessed $data) ? '' : ref $data;
    $n_steps++ if $ref;
  }

  return ($ref||'SCALAR') . ('REF' x $n_steps);
}

sub _try_refkind {
  my ($self, $data) = @_;
  my @try = ($self->_refkind($data));
  push @try, 'SCALAR_or_UNDEF' if $try[0] eq 'SCALAR' || $try[0] eq 'UNDEF';
  push @try, 'FALLBACK';
  return \@try;
}

sub _METHOD_FOR_refkind {
  my ($self, $meth_prefix, $data) = @_;

  my $method;
  for (@{$self->_try_refkind($data)}) {
    $method = $self->can($meth_prefix."_".$_)
      and last;
  }

  return $method || puke "cannot dispatch on '$meth_prefix' for ".$self->_refkind($data);
}


sub _SWITCH_refkind {
  my ($self, $data, $dispatch_table) = @_;

  my $coderef;
  for (@{$self->_try_refkind($data)}) {
    $coderef = $dispatch_table->{$_}
      and last;
  }

  puke "no dispatch entry for ".$self->_refkind($data)
    unless $coderef;

  $coderef->();
}




#======================================================================
# VALUES, GENERATE, AUTOLOAD
#======================================================================

# LDNOTE: original code from nwiger, didn't touch code in that section
# I feel the AUTOLOAD stuff should not be the default, it should
# only be activated on explicit demand by user.

sub values {
    my $self = shift;
    my $data = shift || return;
    puke "Argument to ", __PACKAGE__, "->values must be a \\%hash"
        unless ref $data eq 'HASH';

    my @all_bind;
    foreach my $k ( sort keys %$data ) {
        my $v = $data->{$k};
        $self->_SWITCH_refkind($v, {
          ARRAYREF => sub {
            if ($self->{array_datatypes}) { # array datatype
              push @all_bind, $self->_bindtype($k, $v);
            }
            else {                          # literal SQL with bind
              my ($sql, @bind) = @$v;
              $self->_assert_bindval_matches_bindtype(@bind);
              push @all_bind, @bind;
            }
          },
          ARRAYREFREF => sub { # literal SQL with bind
            my ($sql, @bind) = @${$v};
            $self->_assert_bindval_matches_bindtype(@bind);
            push @all_bind, @bind;
          },
          SCALARREF => sub {  # literal SQL without bind
          },
          SCALAR_or_UNDEF => sub {
            push @all_bind, $self->_bindtype($k, $v);
          },
        });
    }

    return @all_bind;
}

sub generate {
    my $self  = shift;

    my(@sql, @sqlq, @sqlv);

    for (@_) {
        my $ref = ref $_;
        if ($ref eq 'HASH') {
            for my $k (sort keys %$_) {
                my $v = $_->{$k};
                my $r = ref $v;
                my $label = $self->_quote($k);
                if ($r eq 'ARRAY') {
                    # literal SQL with bind
                    my ($sql, @bind) = @$v;
                    $self->_assert_bindval_matches_bindtype(@bind);
                    push @sqlq, "$label = $sql";
                    push @sqlv, @bind;
                } elsif ($r eq 'SCALAR') {
                    # literal SQL without bind
                    push @sqlq, "$label = $$v";
                } else {
                    push @sqlq, "$label = ?";
                    push @sqlv, $self->_bindtype($k, $v);
                }
            }
            push @sql, $self->_sqlcase('set'), join ', ', @sqlq;
        } elsif ($ref eq 'ARRAY') {
            # unlike insert(), assume these are ONLY the column names, i.e. for SQL
            for my $v (@$_) {
                my $r = ref $v;
                if ($r eq 'ARRAY') {   # literal SQL with bind
                    my ($sql, @bind) = @$v;
                    $self->_assert_bindval_matches_bindtype(@bind);
                    push @sqlq, $sql;
                    push @sqlv, @bind;
                } elsif ($r eq 'SCALAR') {  # literal SQL without bind
                    # embedded literal SQL
                    push @sqlq, $$v;
                } else {
                    push @sqlq, '?';
                    push @sqlv, $v;
                }
            }
            push @sql, '(' . join(', ', @sqlq) . ')';
        } elsif ($ref eq 'SCALAR') {
            # literal SQL
            push @sql, $$_;
        } else {
            # strings get case twiddled
            push @sql, $self->_sqlcase($_);
        }
    }

    my $sql = join ' ', @sql;

    # this is pretty tricky
    # if ask for an array, return ($stmt, @bind)
    # otherwise, s/?/shift @sqlv/ to put it inline
    if (wantarray) {
        return ($sql, @sqlv);
    } else {
        1 while $sql =~ s/\?/my $d = shift(@sqlv);
                             ref $d ? $d->[1] : $d/e;
        return $sql;
    }
}


sub DESTROY { 1 }

#sub AUTOLOAD {
#    # This allows us to check for a local, then _form, attr
#    my $self = shift;
#    my($name) = $AUTOLOAD =~ /.*::(.+)/;
#    return $self->generate($name, @_);
#}

1;



__END__

=head1 NAME

SQL::Abstract - Generate SQL from Perl data structures

=head1 SYNOPSIS

    use SQL::Abstract;

    my $sql = SQL::Abstract->new;

    my($stmt, @bind) = $sql->select($table, \@fields, \%where, \@order);

    my($stmt, @bind) = $sql->insert($table, \%fieldvals || \@values);

    my($stmt, @bind) = $sql->update($table, \%fieldvals, \%where);

    my($stmt, @bind) = $sql->delete($table, \%where);

    # Then, use these in your DBI statements
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

    # Just generate the WHERE clause
    my($stmt, @bind) = $sql->where(\%where, \@order);

    # Return values in the same order, for hashed queries
    # See PERFORMANCE section for more details
    my @bind = $sql->values(\%fieldvals);

=head1 DESCRIPTION

This module was inspired by the excellent L<DBIx::Abstract>.
However, in using that module I found that what I really wanted
to do was generate SQL, but still retain complete control over my
statement handles and use the DBI interface. So, I set out to
create an abstract SQL generation module.

While based on the concepts used by L<DBIx::Abstract>, there are
several important differences, especially when it comes to WHERE
clauses. I have modified the concepts used to make the SQL easier
to generate from Perl data structures and, IMO, more intuitive.
The underlying idea is for this module to do what you mean, based
on the data structures you provide it. The big advantage is that
you don't have to modify your code every time your data changes,
as this module figures it out.

To begin with, an SQL INSERT is as easy as just specifying a hash
of C<key=value> pairs:

    my %data = (
        name => 'Jimbo Bobson',
        phone => '123-456-7890',
        address => '42 Sister Lane',
        city => 'St. Louis',
        state => 'Louisiana',
    );

The SQL can then be generated with this:

    my($stmt, @bind) = $sql->insert('people', \%data);

Which would give you something like this:

    $stmt = "INSERT INTO people
                    (address, city, name, phone, state)
                    VALUES (?, ?, ?, ?, ?)";
    @bind = ('42 Sister Lane', 'St. Louis', 'Jimbo Bobson',
             '123-456-7890', 'Louisiana');

These are then used directly in your DBI code:

    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

=head2 Inserting and Updating Arrays

If your database has array types (like for example Postgres),
activate the special option C<< array_datatypes => 1 >>
when creating the C<SQL::Abstract> object.
Then you may use an arrayref to insert and update database array types:

    my $sql = SQL::Abstract->new(array_datatypes => 1);
    my %data = (
        planets => [qw/Mercury Venus Earth Mars/]
    );

    my($stmt, @bind) = $sql->insert('solar_system', \%data);

This results in:

    $stmt = "INSERT INTO solar_system (planets) VALUES (?)"

    @bind = (['Mercury', 'Venus', 'Earth', 'Mars']);


=head2 Inserting and Updating SQL

In order to apply SQL functions to elements of your C<%data> you may
specify a reference to an arrayref for the given hash value. For example,
if you need to execute the Oracle C<to_date> function on a value, you can
say something like this:

    my %data = (
        name => 'Bill',
        date_entered => \["to_date(?,'MM/DD/YYYY')", "03/02/2003"],
    );

The first value in the array is the actual SQL. Any other values are
optional and would be included in the bind values array. This gives
you:

    my($stmt, @bind) = $sql->insert('people', \%data);

    $stmt = "INSERT INTO people (name, date_entered)
                VALUES (?, to_date(?,'MM/DD/YYYY'))";
    @bind = ('Bill', '03/02/2003');

An UPDATE is just as easy, all you change is the name of the function:

    my($stmt, @bind) = $sql->update('people', \%data);

Notice that your C<%data> isn't touched; the module will generate
the appropriately quirky SQL for you automatically. Usually you'll
want to specify a WHERE clause for your UPDATE, though, which is
where handling C<%where> hashes comes in handy...

=head2 Complex where statements

This module can generate pretty complicated WHERE statements
easily. For example, simple C<key=value> pairs are taken to mean
equality, and if you want to see if a field is within a set
of values, you can use an arrayref. Let's say we wanted to
SELECT some data based on this criteria:

    my %where = (
       requestor => 'inna',
       worker => ['nwiger', 'rcwe', 'sfz'],
       status => { '!=', 'completed' }
    );

    my($stmt, @bind) = $sql->select('tickets', '*', \%where);

The above would give you something like this:

    $stmt = "SELECT * FROM tickets WHERE
                ( requestor = ? ) AND ( status != ? )
                AND ( worker = ? OR worker = ? OR worker = ? )";
    @bind = ('inna', 'completed', 'nwiger', 'rcwe', 'sfz');

Which you could then use in DBI code like so:

    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);

Easy, eh?

=head1 FUNCTIONS

The functions are simple. There's one for each major SQL operation,
and a constructor you use first. The arguments are specified in a
similar order to each function (table, then fields, then a where
clause) to try and simplify things.




=head2 new(option => 'value')

The C<new()> function takes a list of options and values, and returns
a new B<SQL::Abstract> object which can then be used to generate SQL
through the methods below. The options accepted are:

=over

=item case

If set to 'lower', then SQL will be generated in all lowercase. By
default SQL is generated in "textbook" case meaning something like:

    SELECT a_field FROM a_table WHERE some_field LIKE '%someval%'

Any setting other than 'lower' is ignored.

=item cmp

This determines what the default comparison operator is. By default
it is C<=>, meaning that a hash like this:

    %where = (name => 'nwiger', email => 'nate@wiger.org');

Will generate SQL like this:

    WHERE name = 'nwiger' AND email = 'nate@wiger.org'

However, you may want loose comparisons by default, so if you set
C<cmp> to C<like> you would get SQL such as:

    WHERE name like 'nwiger' AND email like 'nate@wiger.org'

You can also override the comparsion on an individual basis - see
the huge section on L</"WHERE CLAUSES"> at the bottom.

=item sqltrue, sqlfalse

Expressions for inserting boolean values within SQL statements.
By default these are C<1=1> and C<1=0>. They are used
by the special operators C<-in> and C<-not_in> for generating
correct SQL even when the argument is an empty array (see below).

=item logic

This determines the default logical operator for multiple WHERE
statements in arrays or hashes. If absent, the default logic is "or"
for arrays, and "and" for hashes. This means that a WHERE
array of the form:

    @where = (
        event_date => {'>=', '2/13/99'},
        event_date => {'<=', '4/24/03'},
    );

will generate SQL like this:

    WHERE event_date >= '2/13/99' OR event_date <= '4/24/03'

This is probably not what you want given this query, though (look
at the dates). To change the "OR" to an "AND", simply specify:

    my $sql = SQL::Abstract->new(logic => 'and');

Which will change the above C<WHERE> to:

    WHERE event_date >= '2/13/99' AND event_date <= '4/24/03'

The logic can also be changed locally by inserting
a modifier in front of an arrayref :

    @where = (-and => [event_date => {'>=', '2/13/99'},
                       event_date => {'<=', '4/24/03'} ]);

See the L</"WHERE CLAUSES"> section for explanations.

=item convert

This will automatically convert comparisons using the specified SQL
function for both column and value. This is mostly used with an argument
of C<upper> or C<lower>, so that the SQL will have the effect of
case-insensitive "searches". For example, this:

    $sql = SQL::Abstract->new(convert => 'upper');
    %where = (keywords => 'MaKe iT CAse inSeNSItive');

Will turn out the following SQL:

    WHERE upper(keywords) like upper('MaKe iT CAse inSeNSItive')

The conversion can be C<upper()>, C<lower()>, or any other SQL function
that can be applied symmetrically to fields (actually B<SQL::Abstract> does
not validate this option; it will just pass through what you specify verbatim).

=item bindtype

This is a kludge because many databases suck. For example, you can't
just bind values using DBI's C<execute()> for Oracle C<CLOB> or C<BLOB> fields.
Instead, you have to use C<bind_param()>:

    $sth->bind_param(1, 'reg data');
    $sth->bind_param(2, $lots, {ora_type => ORA_CLOB});

The problem is, B<SQL::Abstract> will normally just return a C<@bind> array,
which loses track of which field each slot refers to. Fear not.

If you specify C<bindtype> in new, you can determine how C<@bind> is returned.
Currently, you can specify either C<normal> (default) or C<columns>. If you
specify C<columns>, you will get an array that looks like this:

    my $sql = SQL::Abstract->new(bindtype => 'columns');
    my($stmt, @bind) = $sql->insert(...);

    @bind = (
        [ 'column1', 'value1' ],
        [ 'column2', 'value2' ],
        [ 'column3', 'value3' ],
    );

You can then iterate through this manually, using DBI's C<bind_param()>.

    $sth->prepare($stmt);
    my $i = 1;
    for (@bind) {
        my($col, $data) = @$_;
        if ($col eq 'details' || $col eq 'comments') {
            $sth->bind_param($i, $data, {ora_type => ORA_CLOB});
        } elsif ($col eq 'image') {
            $sth->bind_param($i, $data, {ora_type => ORA_BLOB});
        } else {
            $sth->bind_param($i, $data);
        }
        $i++;
    }
    $sth->execute;      # execute without @bind now

Now, why would you still use B<SQL::Abstract> if you have to do this crap?
Basically, the advantage is still that you don't have to care which fields
are or are not included. You could wrap that above C<for> loop in a simple
sub called C<bind_fields()> or something and reuse it repeatedly. You still
get a layer of abstraction over manual SQL specification.

Note that if you set L</bindtype> to C<columns>, the C<\[$sql, @bind]>
construct (see L</Literal SQL with placeholders and bind values (subqueries)>)
will expect the bind values in this format.

=item quote_char

This is the character that a table or column name will be quoted
with.  By default this is an empty string, but you could set it to
the character C<`>, to generate SQL like this:

  SELECT `a_field` FROM `a_table` WHERE `some_field` LIKE '%someval%'

Alternatively, you can supply an array ref of two items, the first being the left
hand quote character, and the second the right hand quote character. For
example, you could supply C<['[',']']> for SQL Server 2000 compliant quotes
that generates SQL like this:

  SELECT [a_field] FROM [a_table] WHERE [some_field] LIKE '%someval%'

Quoting is useful if you have tables or columns names that are reserved
words in your database's SQL dialect.

=item name_sep

This is the character that separates a table and column name.  It is
necessary to specify this when the C<quote_char> option is selected,
so that tables and column names can be individually quoted like this:

  SELECT `table`.`one_field` FROM `table` WHERE `table`.`other_field` = 1

=item injection_guard

A regular expression C<qr/.../> that is applied to any C<-function> and unquoted
column name specified in a query structure. This is a safety mechanism to avoid
injection attacks when mishandling user input e.g.:

  my %condition_as_column_value_pairs = get_values_from_user();
  $sqla->select( ... , \%condition_as_column_value_pairs );

If the expression matches an exception is thrown. Note that literal SQL
supplied via C<\'...'> or C<\['...']> is B<not> checked in any way.

Defaults to checking for C<;> and the C<GO> keyword (TransactSQL)

=item array_datatypes

When this option is true, arrayrefs in INSERT or UPDATE are
interpreted as array datatypes and are passed directly
to the DBI layer.
When this option is false, arrayrefs are interpreted
as literal SQL, just like refs to arrayrefs
(but this behavior is for backwards compatibility; when writing
new queries, use the "reference to arrayref" syntax
for literal SQL).


=item special_ops

Takes a reference to a list of "special operators"
to extend the syntax understood by L<SQL::Abstract>.
See section L</"SPECIAL OPERATORS"> for details.

=item unary_ops

Takes a reference to a list of "unary operators"
to extend the syntax understood by L<SQL::Abstract>.
See section L</"UNARY OPERATORS"> for details.



=back

=head2 insert($table, \@values || \%fieldvals, \%options)

This is the simplest function. You simply give it a table name
and either an arrayref of values or hashref of field/value pairs.
It returns an SQL INSERT statement and a list of bind values.
See the sections on L</"Inserting and Updating Arrays"> and
L</"Inserting and Updating SQL"> for information on how to insert
with those data types.

The optional C<\%options> hash reference may contain additional
options to generate the insert SQL. Currently supported options
are:

=over 4

=item returning

Takes either a scalar of raw SQL fields, or an array reference of
field names, and adds on an SQL C<RETURNING> statement at the end.
This allows you to return data generated by the insert statement
(such as row IDs) without performing another C<SELECT> statement.
Note, however, this is not part of the SQL standard and may not
be supported by all database engines.

=back

=head2 update($table, \%fieldvals, \%where)

This takes a table, hashref of field/value pairs, and an optional
hashref L<WHERE clause|/WHERE CLAUSES>. It returns an SQL UPDATE function and a list
of bind values.
See the sections on L</"Inserting and Updating Arrays"> and
L</"Inserting and Updating SQL"> for information on how to insert
with those data types.

=head2 select($source, $fields, $where, $order)

This returns a SQL SELECT statement and associated list of bind values, as
specified by the arguments  :

=over

=item $source

Specification of the 'FROM' part of the statement.
The argument can be either a plain scalar (interpreted as a table
name, will be quoted), or an arrayref (interpreted as a list
of table names, joined by commas, quoted), or a scalarref
(literal table name, not quoted), or a ref to an arrayref
(list of literal table names, joined by commas, not quoted).

=item $fields

Specification of the list of fields to retrieve from
the source.
The argument can be either an arrayref (interpreted as a list
of field names, will be joined by commas and quoted), or a
plain scalar (literal SQL, not quoted).
Please observe that this API is not as flexible as for
the first argument C<$table>, for backwards compatibility reasons.

=item $where

Optional argument to specify the WHERE part of the query.
The argument is most often a hashref, but can also be
an arrayref or plain scalar --
see section L<WHERE clause|/"WHERE CLAUSES"> for details.

=item $order

Optional argument to specify the ORDER BY part of the query.
The argument can be a scalar, a hashref or an arrayref
-- see section L<ORDER BY clause|/"ORDER BY CLAUSES">
for details.

=back


=head2 delete($table, \%where)

This takes a table name and optional hashref L<WHERE clause|/WHERE CLAUSES>.
It returns an SQL DELETE statement and list of bind values.

=head2 where(\%where, \@order)

This is used to generate just the WHERE clause. For example,
if you have an arbitrary data structure and know what the
rest of your SQL is going to look like, but want an easy way
to produce a WHERE clause, use this. It returns an SQL WHERE
clause and list of bind values.


=head2 values(\%data)

This just returns the values from the hash C<%data>, in the same
order that would be returned from any of the other above queries.
Using this allows you to markedly speed up your queries if you
are affecting lots of rows. See below under the L</"PERFORMANCE"> section.

=head2 generate($any, 'number', $of, \@data, $struct, \%types)

Warning: This is an experimental method and subject to change.

This returns arbitrarily generated SQL. It's a really basic shortcut.
It will return two different things, depending on return context:

    my($stmt, @bind) = $sql->generate('create table', \$table, \@fields);
    my $stmt_and_val = $sql->generate('create table', \$table, \@fields);

These would return the following:

    # First calling form
    $stmt = "CREATE TABLE test (?, ?)";
    @bind = (field1, field2);

    # Second calling form
    $stmt_and_val = "CREATE TABLE test (field1, field2)";

Depending on what you're trying to do, it's up to you to choose the correct
format. In this example, the second form is what you would want.

By the same token:

    $sql->generate('alter session', { nls_date_format => 'MM/YY' });

Might give you:

    ALTER SESSION SET nls_date_format = 'MM/YY'

You get the idea. Strings get their case twiddled, but everything
else remains verbatim.

=head1 WHERE CLAUSES

=head2 Introduction

This module uses a variation on the idea from L<DBIx::Abstract>. It
is B<NOT>, repeat I<not> 100% compatible. B<The main logic of this
module is that things in arrays are OR'ed, and things in hashes
are AND'ed.>

The easiest way to explain is to show lots of examples. After
each C<%where> hash shown, it is assumed you used:

    my($stmt, @bind) = $sql->where(\%where);

However, note that the C<%where> hash can be used directly in any
of the other functions as well, as described above.

=head2 Key-value pairs

So, let's get started. To begin, a simple hash:

    my %where  = (
        user   => 'nwiger',
        status => 'completed'
    );

Is converted to SQL C<key = val> statements:

    $stmt = "WHERE user = ? AND status = ?";
    @bind = ('nwiger', 'completed');

One common thing I end up doing is having a list of values that
a field can be in. To do this, simply specify a list inside of
an arrayref:

    my %where  = (
        user   => 'nwiger',
        status => ['assigned', 'in-progress', 'pending'];
    );

This simple code will create the following:

    $stmt = "WHERE user = ? AND ( status = ? OR status = ? OR status = ? )";
    @bind = ('nwiger', 'assigned', 'in-progress', 'pending');

A field associated to an empty arrayref will be considered a
logical false and will generate 0=1.

=head2 Tests for NULL values

If the value part is C<undef> then this is converted to SQL <IS NULL>

    my %where  = (
        user   => 'nwiger',
        status => undef,
    );

becomes:

    $stmt = "WHERE user = ? AND status IS NULL";
    @bind = ('nwiger');

To test if a column IS NOT NULL:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', undef },
    );

=head2 Specific comparison operators

If you want to specify a different type of operator for your comparison,
you can use a hashref for a given column:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', 'completed' }
    );

Which would generate:

    $stmt = "WHERE user = ? AND status != ?";
    @bind = ('nwiger', 'completed');

To test against multiple values, just enclose the values in an arrayref:

    status => { '=', ['assigned', 'in-progress', 'pending'] };

Which would give you:

    "WHERE status = ? OR status = ? OR status = ?"


The hashref can also contain multiple pairs, in which case it is expanded
into an C<AND> of its elements:

    my %where  = (
        user   => 'nwiger',
        status => { '!=', 'completed', -not_like => 'pending%' }
    );

    # Or more dynamically, like from a form
    $where{user} = 'nwiger';
    $where{status}{'!='} = 'completed';
    $where{status}{'-not_like'} = 'pending%';

    # Both generate this
    $stmt = "WHERE user = ? AND status != ? AND status NOT LIKE ?";
    @bind = ('nwiger', 'completed', 'pending%');


To get an OR instead, you can combine it with the arrayref idea:

    my %where => (
         user => 'nwiger',
         priority => [ { '=', 2 }, { '>', 5 } ]
    );

Which would generate:

    $stmt = "WHERE ( priority = ? OR priority > ? ) AND user = ?";
    @bind = ('2', '5', 'nwiger');

If you want to include literal SQL (with or without bind values), just use a
scalar reference or array reference as the value:

    my %where  = (
        date_entered => { '>' => \["to_date(?, 'MM/DD/YYYY')", "11/26/2008"] },
        date_expires => { '<' => \"now()" }
    );

Which would generate:

    $stmt = "WHERE date_entered > "to_date(?, 'MM/DD/YYYY') AND date_expires < now()";
    @bind = ('11/26/2008');


=head2 Logic and nesting operators

In the example above,
there is a subtle trap if you want to say something like
this (notice the C<AND>):

    WHERE priority != ? AND priority != ?

Because, in Perl you I<can't> do this:

    priority => { '!=', 2, '!=', 1 }

As the second C<!=> key will obliterate the first. The solution
is to use the special C<-modifier> form inside an arrayref:

    priority => [ -and => {'!=', 2},
                          {'!=', 1} ]


Normally, these would be joined by C<OR>, but the modifier tells it
to use C<AND> instead. (Hint: You can use this in conjunction with the
C<logic> option to C<new()> in order to change the way your queries
work by default.) B<Important:> Note that the C<-modifier> goes
B<INSIDE> the arrayref, as an extra first element. This will
B<NOT> do what you think it might:

    priority => -and => [{'!=', 2}, {'!=', 1}]   # WRONG!

Here is a quick list of equivalencies, since there is some overlap:

    # Same
    status => {'!=', 'completed', 'not like', 'pending%' }
    status => [ -and => {'!=', 'completed'}, {'not like', 'pending%'}]

    # Same
    status => {'=', ['assigned', 'in-progress']}
    status => [ -or => {'=', 'assigned'}, {'=', 'in-progress'}]
    status => [ {'=', 'assigned'}, {'=', 'in-progress'} ]



=head2 Special operators : IN, BETWEEN, etc.

You can also use the hashref format to compare a list of fields using the
C<IN> comparison operator, by specifying the list as an arrayref:

    my %where  = (
        status   => 'completed',
        reportid => { -in => [567, 2335, 2] }
    );

Which would generate:

    $stmt = "WHERE status = ? AND reportid IN (?,?,?)";
    @bind = ('completed', '567', '2335', '2');

The reverse operator C<-not_in> generates SQL C<NOT IN> and is used in
the same way.

If the argument to C<-in> is an empty array, 'sqlfalse' is generated
(by default : C<1=0>). Similarly, C<< -not_in => [] >> generates
'sqltrue' (by default : C<1=1>).

In addition to the array you can supply a chunk of literal sql or
literal sql with bind:

    my %where = {
      customer => { -in => \[
        'SELECT cust_id FROM cust WHERE balance > ?',
        2000,
      ],
      status => { -in => \'SELECT status_codes FROM states' },
    };

would generate:

    $stmt = "WHERE (
          customer IN ( SELECT cust_id FROM cust WHERE balance > ? )
      AND status IN ( SELECT status_codes FROM states )
    )";
    @bind = ('2000');



Another pair of operators is C<-between> and C<-not_between>,
used with an arrayref of two values:

    my %where  = (
        user   => 'nwiger',
        completion_date => {
           -not_between => ['2002-10-01', '2003-02-06']
        }
    );

Would give you:

    WHERE user = ? AND completion_date NOT BETWEEN ( ? AND ? )

Just like with C<-in> all plausible combinations of literal SQL
are possible:

    my %where = {
      start0 => { -between => [ 1, 2 ] },
      start1 => { -between => \["? AND ?", 1, 2] },
      start2 => { -between => \"lower(x) AND upper(y)" },
      start3 => { -between => [
        \"lower(x)",
        \["upper(?)", 'stuff' ],
      ] },
    };

Would give you:

    $stmt = "WHERE (
          ( start0 BETWEEN ? AND ?                )
      AND ( start1 BETWEEN ? AND ?                )
      AND ( start2 BETWEEN lower(x) AND upper(y)  )
      AND ( start3 BETWEEN lower(x) AND upper(?)  )
    )";
    @bind = (1, 2, 1, 2, 'stuff');


These are the two builtin "special operators"; but the
list can be expanded : see section L</"SPECIAL OPERATORS"> below.

=head2 Unary operators: bool

If you wish to test against boolean columns or functions within your
database you can use the C<-bool> and C<-not_bool> operators. For
example to test the column C<is_user> being true and the column
C<is_enabled> being false you would use:-

    my %where  = (
        -bool       => 'is_user',
        -not_bool   => 'is_enabled',
    );

Would give you:

    WHERE is_user AND NOT is_enabled

If a more complex combination is required, testing more conditions,
then you should use the and/or operators:-

    my %where  = (
        -and           => [
            -bool      => 'one',
            -bool      => 'two',
            -bool      => 'three',
            -not_bool  => 'four',
        ],
    );

Would give you:

    WHERE one AND two AND three AND NOT four


=head2 Nested conditions, -and/-or prefixes

So far, we've seen how multiple conditions are joined with a top-level
C<AND>.  We can change this by putting the different conditions we want in
hashes and then putting those hashes in an array. For example:

    my @where = (
        {
            user   => 'nwiger',
            status => { -like => ['pending%', 'dispatched'] },
        },
        {
            user   => 'robot',
            status => 'unassigned',
        }
    );

This data structure would create the following:

    $stmt = "WHERE ( user = ? AND ( status LIKE ? OR status LIKE ? ) )
                OR ( user = ? AND status = ? ) )";
    @bind = ('nwiger', 'pending', 'dispatched', 'robot', 'unassigned');


Clauses in hashrefs or arrayrefs can be prefixed with an C<-and> or C<-or>
to change the logic inside :

    my @where = (
         -and => [
            user => 'nwiger',
            [
                -and => [ workhrs => {'>', 20}, geo => 'ASIA' ],
                -or => { workhrs => {'<', 50}, geo => 'EURO' },
            ],
        ],
    );

That would yield:

    WHERE ( user = ? AND (
               ( workhrs > ? AND geo = ? )
            OR ( workhrs < ? OR geo = ? )
          ) )

=head3 Algebraic inconsistency, for historical reasons

C<Important note>: when connecting several conditions, the C<-and->|C<-or>
operator goes C<outside> of the nested structure; whereas when connecting
several constraints on one column, the C<-and> operator goes
C<inside> the arrayref. Here is an example combining both features :

   my @where = (
     -and => [a => 1, b => 2],
     -or  => [c => 3, d => 4],
      e   => [-and => {-like => 'foo%'}, {-like => '%bar'} ]
   )

yielding

  WHERE ( (    ( a = ? AND b = ? )
            OR ( c = ? OR d = ? )
            OR ( e LIKE ? AND e LIKE ? ) ) )

This difference in syntax is unfortunate but must be preserved for
historical reasons. So be careful : the two examples below would
seem algebraically equivalent, but they are not

  {col => [-and => {-like => 'foo%'}, {-like => '%bar'}]}
  # yields : WHERE ( ( col LIKE ? AND col LIKE ? ) )

  [-and => {col => {-like => 'foo%'}, {col => {-like => '%bar'}}]]
  # yields : WHERE ( ( col LIKE ? OR col LIKE ? ) )


=head2 Literal SQL and value type operators

The basic premise of SQL::Abstract is that in WHERE specifications the "left
side" is a column name and the "right side" is a value (normally rendered as
a placeholder). This holds true for both hashrefs and arrayref pairs as you
see in the L</WHERE CLAUSES> examples above. Sometimes it is necessary to
alter this behavior. There are several ways of doing so.

=head3 -ident

This is a virtual operator that signals the string to its right side is an
identifier (a column name) and not a value. For example to compare two
columns you would write:

    my %where = (
        priority => { '<', 2 },
        requestor => { -ident => 'submitter' },
    );

which creates:

    $stmt = "WHERE priority < ? AND requestor = submitter";
    @bind = ('2');

If you are maintaining legacy code you may see a different construct as
described in L</Deprecated usage of Literal SQL>, please use C<-ident> in new
code.

=head3 -value

This is a virtual operator that signals that the construct to its right side
is a value to be passed to DBI. This is for example necessary when you want
to write a where clause against an array (for RDBMS that support such
datatypes). For example:

    my %where = (
        array => { -value => [1, 2, 3] }
    );

will result in:

    $stmt = 'WHERE array = ?';
    @bind = ([1, 2, 3]);

Note that if you were to simply say:

    my %where = (
        array => [1, 2, 3]
    );

the result would porbably be not what you wanted:

    $stmt = 'WHERE array = ? OR array = ? OR array = ?';
    @bind = (1, 2, 3);

=head3 Literal SQL

Finally, sometimes only literal SQL will do. To include a random snippet
of SQL verbatim, you specify it as a scalar reference. Consider this only
as a last resort. Usually there is a better way. For example:

    my %where = (
        priority => { '<', 2 },
        requestor => { -in => \'(SELECT name FROM hitmen)' },
    );

Would create:

    $stmt = "WHERE priority < ? AND requestor IN (SELECT name FROM hitmen)"
    @bind = (2);

Note that in this example, you only get one bind parameter back, since
the verbatim SQL is passed as part of the statement.

=head4 CAVEAT

  Never use untrusted input as a literal SQL argument - this is a massive
  security risk (there is no way to check literal snippets for SQL
  injections and other nastyness). If you need to deal with untrusted input
  use literal SQL with placeholders as described next.

=head3 Literal SQL with placeholders and bind values (subqueries)

If the literal SQL to be inserted has placeholders and bind values,
use a reference to an arrayref (yes this is a double reference --
not so common, but perfectly legal Perl). For example, to find a date
in Postgres you can use something like this:

    my %where = (
       date_column => \[q/= date '2008-09-30' - ?::integer/, 10/]
    )

This would create:

    $stmt = "WHERE ( date_column = date '2008-09-30' - ?::integer )"
    @bind = ('10');

Note that you must pass the bind values in the same format as they are returned
by L</where>. That means that if you set L</bindtype> to C<columns>, you must
provide the bind values in the C<< [ column_meta => value ] >> format, where
C<column_meta> is an opaque scalar value; most commonly the column name, but
you can use any scalar value (including references and blessed references),
L<SQL::Abstract> will simply pass it through intact. So if C<bindtype> is set
to C<columns> the above example will look like:

    my %where = (
       date_column => \[q/= date '2008-09-30' - ?::integer/, [ dummy => 10 ]/]
    )

Literal SQL is especially useful for nesting parenthesized clauses in the
main SQL query. Here is a first example :

  my ($sub_stmt, @sub_bind) = ("SELECT c1 FROM t1 WHERE c2 < ? AND c3 LIKE ?",
                               100, "foo%");
  my %where = (
    foo => 1234,
    bar => \["IN ($sub_stmt)" => @sub_bind],
  );

This yields :

  $stmt = "WHERE (foo = ? AND bar IN (SELECT c1 FROM t1
                                             WHERE c2 < ? AND c3 LIKE ?))";
  @bind = (1234, 100, "foo%");

Other subquery operators, like for example C<"E<gt> ALL"> or C<"NOT IN">,
are expressed in the same way. Of course the C<$sub_stmt> and
its associated bind values can be generated through a former call
to C<select()> :

  my ($sub_stmt, @sub_bind)
     = $sql->select("t1", "c1", {c2 => {"<" => 100},
                                 c3 => {-like => "foo%"}});
  my %where = (
    foo => 1234,
    bar => \["> ALL ($sub_stmt)" => @sub_bind],
  );

In the examples above, the subquery was used as an operator on a column;
but the same principle also applies for a clause within the main C<%where>
hash, like an EXISTS subquery :

  my ($sub_stmt, @sub_bind)
     = $sql->select("t1", "*", {c1 => 1, c2 => \"> t0.c0"});
  my %where = ( -and => [
    foo   => 1234,
    \["EXISTS ($sub_stmt)" => @sub_bind],
  ]);

which yields

  $stmt = "WHERE (foo = ? AND EXISTS (SELECT * FROM t1
                                        WHERE c1 = ? AND c2 > t0.c0))";
  @bind = (1234, 1);


Observe that the condition on C<c2> in the subquery refers to
column C<t0.c0> of the main query : this is I<not> a bind
value, so we have to express it through a scalar ref.
Writing C<< c2 => {">" => "t0.c0"} >> would have generated
C<< c2 > ? >> with bind value C<"t0.c0"> ... not exactly
what we wanted here.

Finally, here is an example where a subquery is used
for expressing unary negation:

  my ($sub_stmt, @sub_bind)
     = $sql->where({age => [{"<" => 10}, {">" => 20}]});
  $sub_stmt =~ s/^ where //i; # don't want "WHERE" in the subclause
  my %where = (
        lname  => {like => '%son%'},
        \["NOT ($sub_stmt)" => @sub_bind],
    );

This yields

  $stmt = "lname LIKE ? AND NOT ( age < ? OR age > ? )"
  @bind = ('%son%', 10, 20)

=head3 Deprecated usage of Literal SQL

Below are some examples of archaic use of literal SQL. It is shown only as
reference for those who deal with legacy code. Each example has a much
better, cleaner and safer alternative that users should opt for in new code.

=over

=item *

    my %where = ( requestor => \'IS NOT NULL' )

    $stmt = "WHERE requestor IS NOT NULL"

This used to be the way of generating NULL comparisons, before the handling
of C<undef> got formalized. For new code please use the superior syntax as
described in L</Tests for NULL values>.

=item *

    my %where = ( requestor => \'= submitter' )

    $stmt = "WHERE requestor = submitter"

This used to be the only way to compare columns. Use the superior L</-ident>
method for all new code. For example an identifier declared in such a way
will be properly quoted if L</quote_char> is properly set, while the legacy
form will remain as supplied.

=item *

    my %where = ( is_ready  => \"", completed => { '>', '2012-12-21' } )

    $stmt = "WHERE completed > ? AND is_ready"
    @bind = ('2012-12-21')

Using an empty string literal used to be the only way to express a boolean.
For all new code please use the much more readable
L<-bool|/Unary operators: bool> operator.

=back

=head2 Conclusion

These pages could go on for a while, since the nesting of the data
structures this module can handle are pretty much unlimited (the
module implements the C<WHERE> expansion as a recursive function
internally). Your best bet is to "play around" with the module a
little to see how the data structures behave, and choose the best
format for your data based on that.

And of course, all the values above will probably be replaced with
variables gotten from forms or the command line. After all, if you
knew everything ahead of time, you wouldn't have to worry about
dynamically-generating SQL and could just hardwire it into your
script.

=head1 ORDER BY CLAUSES

Some functions take an order by clause. This can either be a scalar (just a
column name,) a hash of C<< { -desc => 'col' } >> or C<< { -asc => 'col' } >>,
or an array of either of the two previous forms. Examples:

               Given            |         Will Generate
    ----------------------------------------------------------
                                |
    \'colA DESC'                | ORDER BY colA DESC
                                |
    'colA'                      | ORDER BY colA
                                |
    [qw/colA colB/]             | ORDER BY colA, colB
                                |
    {-asc  => 'colA'}           | ORDER BY colA ASC
                                |
    {-desc => 'colB'}           | ORDER BY colB DESC
                                |
    ['colA', {-asc => 'colB'}]  | ORDER BY colA, colB ASC
                                |
    { -asc => [qw/colA colB/] } | ORDER BY colA ASC, colB ASC
                                |
    [                           |
      { -asc => 'colA' },       | ORDER BY colA ASC, colB DESC,
      { -desc => [qw/colB/],    |          colC ASC, colD ASC
      { -asc => [qw/colC colD/],|
    ]                           |
    ===========================================================



=head1 SPECIAL OPERATORS

  my $sqlmaker = SQL::Abstract->new(special_ops => [
     {
      regex => qr/.../,
      handler => sub {
        my ($self, $field, $op, $arg) = @_;
        ...
      },
     },
     {
      regex => qr/.../,
      handler => 'method_name',
     },
   ]);

A "special operator" is a SQL syntactic clause that can be
applied to a field, instead of a usual binary operator.
For example :

   WHERE field IN (?, ?, ?)
   WHERE field BETWEEN ? AND ?
   WHERE MATCH(field) AGAINST (?, ?)

Special operators IN and BETWEEN are fairly standard and therefore
are builtin within C<SQL::Abstract> (as the overridable methods
C<_where_field_IN> and C<_where_field_BETWEEN>). For other operators,
like the MATCH .. AGAINST example above which is specific to MySQL,
you can write your own operator handlers - supply a C<special_ops>
argument to the C<new> method. That argument takes an arrayref of
operator definitions; each operator definition is a hashref with two
entries:

=over

=item regex

the regular expression to match the operator

=item handler

Either a coderef or a plain scalar method name. In both cases
the expected return is C<< ($sql, @bind) >>.

When supplied with a method name, it is simply called on the
L<SQL::Abstract/> object as:

 $self->$method_name ($field, $op, $arg)

 Where:

  $op is the part that matched the handler regex
  $field is the LHS of the operator
  $arg is the RHS

When supplied with a coderef, it is called as:

 $coderef->($self, $field, $op, $arg)


=back

For example, here is an implementation
of the MATCH .. AGAINST syntax for MySQL

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

  ]);


=head1 UNARY OPERATORS

  my $sqlmaker = SQL::Abstract->new(unary_ops => [
     {
      regex => qr/.../,
      handler => sub {
        my ($self, $op, $arg) = @_;
        ...
      },
     },
     {
      regex => qr/.../,
      handler => 'method_name',
     },
   ]);

A "unary operator" is a SQL syntactic clause that can be
applied to a field - the operator goes before the field

You can write your own operator handlers - supply a C<unary_ops>
argument to the C<new> method. That argument takes an arrayref of
operator definitions; each operator definition is a hashref with two
entries:

=over

=item regex

the regular expression to match the operator

=item handler

Either a coderef or a plain scalar method name. In both cases
the expected return is C<< $sql >>.

When supplied with a method name, it is simply called on the
L<SQL::Abstract/> object as:

 $self->$method_name ($op, $arg)

 Where:

  $op is the part that matched the handler regex
  $arg is the RHS or argument of the operator

When supplied with a coderef, it is called as:

 $coderef->($self, $op, $arg)


=back


=head1 PERFORMANCE

Thanks to some benchmarking by Mark Stosberg, it turns out that
this module is many orders of magnitude faster than using C<DBIx::Abstract>.
I must admit this wasn't an intentional design issue, but it's a
byproduct of the fact that you get to control your C<DBI> handles
yourself.

To maximize performance, use a code snippet like the following:

    # prepare a statement handle using the first row
    # and then reuse it for the rest of the rows
    my($sth, $stmt);
    for my $href (@array_of_hashrefs) {
        $stmt ||= $sql->insert('table', $href);
        $sth  ||= $dbh->prepare($stmt);
        $sth->execute($sql->values($href));
    }

The reason this works is because the keys in your C<$href> are sorted
internally by B<SQL::Abstract>. Thus, as long as your data retains
the same structure, you only have to generate the SQL the first time
around. On subsequent queries, simply use the C<values> function provided
by this module to return your values in the correct order.

However this depends on the values having the same type - if, for
example, the values of a where clause may either have values
(resulting in sql of the form C<column = ?> with a single bind
value), or alternatively the values might be C<undef> (resulting in
sql of the form C<column IS NULL> with no bind value) then the
caching technique suggested will not work.

=head1 FORMBUILDER

If you use my C<CGI::FormBuilder> module at all, you'll hopefully
really like this part (I do, at least). Building up a complex query
can be as simple as the following:

    #!/usr/bin/perl

    use CGI::FormBuilder;
    use SQL::Abstract;

    my $form = CGI::FormBuilder->new(...);
    my $sql  = SQL::Abstract->new;

    if ($form->submitted) {
        my $field = $form->field;
        my $id = delete $field->{id};
        my($stmt, @bind) = $sql->update('table', $field, {id => $id});
    }

Of course, you would still have to connect using C<DBI> to run the
query, but the point is that if you make your form look like your
table, the actual query script can be extremely simplistic.

If you're B<REALLY> lazy (I am), check out C<HTML::QuickTable> for
a fast interface to returning and formatting data. I frequently
use these three modules together to write complex database query
apps in under 50 lines.

=head1 REPO

=over

=item * gitweb: L<http://git.shadowcat.co.uk/gitweb/gitweb.cgi?p=dbsrgits/SQL-Abstract.git>

=item * git: L<git://git.shadowcat.co.uk/dbsrgits/SQL-Abstract.git>

=back

=head1 CHANGES

Version 1.50 was a major internal refactoring of C<SQL::Abstract>.
Great care has been taken to preserve the I<published> behavior
documented in previous versions in the 1.* family; however,
some features that were previously undocumented, or behaved
differently from the documentation, had to be changed in order
to clarify the semantics. Hence, client code that was relying
on some dark areas of C<SQL::Abstract> v1.*
B<might behave differently> in v1.50.

The main changes are :

=over

=item *

support for literal SQL through the C<< \ [$sql, bind] >> syntax.

=item *

support for the { operator => \"..." } construct (to embed literal SQL)

=item *

support for the { operator => \["...", @bind] } construct (to embed literal SQL with bind values)

=item *

optional support for L<array datatypes|/"Inserting and Updating Arrays">

=item *

defensive programming : check arguments

=item *

fixed bug with global logic, which was previously implemented
through global variables yielding side-effects. Prior versions would
interpret C<< [ {cond1, cond2}, [cond3, cond4] ] >>
as C<< "(cond1 AND cond2) OR (cond3 AND cond4)" >>.
Now this is interpreted
as C<< "(cond1 AND cond2) OR (cond3 OR cond4)" >>.


=item *

fixed semantics of  _bindtype on array args

=item *

dropped the C<_anoncopy> of the %where tree. No longer necessary,
we just avoid shifting arrays within that tree.

=item *

dropped the C<_modlogic> function

=back

=head1 ACKNOWLEDGEMENTS

There are a number of individuals that have really helped out with
this module. Unfortunately, most of them submitted bugs via CPAN
so I have no idea who they are! But the people I do know are:

    Ash Berlin (order_by hash term support)
    Matt Trout (DBIx::Class support)
    Mark Stosberg (benchmarking)
    Chas Owens (initial "IN" operator support)
    Philip Collins (per-field SQL functions)
    Eric Kolve (hashref "AND" support)
    Mike Fragassi (enhancements to "BETWEEN" and "LIKE")
    Dan Kubb (support for "quote_char" and "name_sep")
    Guillermo Roditi (patch to cleanup "IN" and "BETWEEN", fix and tests for _order_by)
    Laurent Dami (internal refactoring, extensible list of special operators, literal SQL)
    Norbert Buchmuller (support for literal SQL in hashpair, misc. fixes & tests)
    Peter Rabbitson (rewrite of SQLA::Test, misc. fixes & tests)
    Oliver Charles (support for "RETURNING" after "INSERT")

Thanks!

=head1 SEE ALSO

L<DBIx::Class>, L<DBIx::Abstract>, L<CGI::FormBuilder>, L<HTML::QuickTable>.

=head1 AUTHOR

Copyright (c) 2001-2007 Nathan Wiger <nwiger@cpan.org>. All Rights Reserved.

This module is actively maintained by Matt Trout <mst@shadowcatsystems.co.uk>

For support, your best bet is to try the C<DBIx::Class> users mailing list.
While not an official support venue, C<DBIx::Class> makes heavy use of
C<SQL::Abstract>, and as such list members there are very familiar with
how to create queries.

=head1 LICENSE

This module is free software; you may copy this under the same
terms as perl itself (either the GNU General Public License or
the Artistic License)

=cut

