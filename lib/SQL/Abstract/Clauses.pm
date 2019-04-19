package SQL::Abstract::Clauses;

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
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
  $self->{render}{select} = sub { shift->_render_statement(@_) };
  $self->{expand_clause}{"select.$_"} = "_expand_select_clause_$_"
    for @{$self->{clauses_of}{select}};
  $self->{clauses_of}{update} = [ qw(target set where returning) ];
  $self->{expand}{update} = sub { shift->_expand_statement(@_) };
  $self->{render}{update} = sub { shift->_render_statement(@_) };
  $self->{expand_clause}{"update.$_"} = "_expand_update_clause_$_"
    for @{$self->{clauses_of}{update}};
  $self->{expand_clause}{'update.update'} = '_expand_update_clause_target';
  $self->{render_clause}{'update.target'} = sub {
    my ($self, undef, $target) = @_;
    $self->join_query_parts(' ', $self->format_keyword('update'), $target);
  };
  $self->{clauses_of}{delete} = [ qw(target where returning) ];
  $self->{expand}{delete} = sub { shift->_expand_statement(@_) };
  $self->{render}{delete} = sub { shift->_render_statement(@_) };
  $self->{expand_clause}{"delete.$_"} = "_expand_delete_clause_$_"
    for @{$self->{clauses_of}{delete}};
  $self->{expand_clause}{"delete.from"} = '_expand_delete_clause_target';
  $self->{render_clause}{'delete.target'} = sub {
    my ($self, undef, $from) = @_;
    $self->join_query_parts(' ', $self->format_keyword('delete from'), $from);
  };
  $self->{clauses_of}{insert} = [
    'target', 'fields', 'from', 'returning'
  ];
  $self->{expand}{insert} = sub { shift->_expand_statement(@_) };
  $self->{render}{insert} = sub { shift->_render_statement(@_) };
  $self->{expand_clause}{"insert.$_"} = "_expand_insert_clause_$_"
    for @{$self->{clauses_of}{insert}};
  $self->{expand_clause}{'insert.into'} = '_expand_insert_clause_target';
  $self->{expand_clause}{'insert.values'} = '_expand_insert_clause_from';
  $self->{render_clause}{'insert.fields'} = sub {
    return $_[0]->render_aqt($_[2]);
  };
  $self->{render_clause}{'insert.target'} = sub {
    my ($self, undef, $from) = @_;
    $self->join_query_parts(' ', $self->format_keyword('insert into'), $from);
  };
  $self->{render_clause}{'insert.from'} = sub {
    return $_[0]->render_aqt($_[2], 1);
  };
  $self->{expand}{values} = '_expand_values';
  $self->{render}{values} = '_render_values';
  $self->{expand}{exists} = sub {
    $_[0]->_expand_op(undef, [ exists => $_[2] ]);
  };
  $self->{render}{convert_where} = sub {
    my $self = shift;
    local $self->{convert_where} = $self->{convert};
    $self->render_aqt($_[1]);
  };
  return $self;
}

sub _expand_select_clause_select {
  my ($self, undef, $select) = @_;
  +(select => $self->_expand_maybe_list_expr($select, -ident));
}

sub _expand_select_clause_from {
  my ($self, undef, $from) = @_;
  +(from => $self->_expand_maybe_list_expr($from, -ident));
}

sub _expand_select_clause_where {
  my ($self, undef, $where) = @_;
  my $exp = $self->expand_expr($where);
  +(where => ($self->{convert} ? +{ -convert_where => $exp } : $exp));
}

sub _expand_select_clause_order_by {
  my ($self, undef, $order_by) = @_;
  +(order_by => $self->_expand_order_by($order_by));
}

sub _expand_update_clause_target {
  my ($self, undef, $target) = @_;
  +(target => $self->_expand_maybe_list_expr($target, -ident));
}

sub _expand_update_clause_set {
  return $_[2] if ref($_[2]) eq 'HASH' and ($_[2]->{-op}||[''])->[0] eq ',';
  +(set => $_[0]->_expand_update_set_values($_[1], $_[2]));
}

sub _expand_update_clause_where {
  +(where => $_[0]->expand_expr($_[2]));
}

sub _expand_update_clause_returning {
  +(returning => $_[0]->_expand_maybe_list_expr($_[2], -ident));
}

sub _expand_delete_clause_target {
  +(target => $_[0]->_expand_maybe_list_expr($_[2], -ident));
}

sub _expand_delete_clause_where { +(where => $_[0]->expand_expr($_[2])); }

sub _expand_delete_clause_returning {
  +(returning => $_[0]->_expand_maybe_list_expr($_[2], -ident));
}

sub _expand_statement {
  my ($self, $type, $args) = @_;
  my $ec = $self->{expand_clause};
  if ($args->{_}) {
    $args = { %$args };
    $args->{$type} = delete $args->{_}
  }
  return +{ "-${type}" => +{
    map {
      my $val = $args->{$_};
      if (defined($val) and my $exp = $ec->{"${type}.$_"}) {
        if ((my (@exp) = $self->$exp($_ => $val)) == 1) {
          ($_ => $exp[0])
        } else {
          @exp
        }
      } else {
        ($_ => $self->expand_expr($val))
      }
    } sort keys %$args
  } };
}

sub _render_statement {
  my ($self, $type, $args) = @_;
  my @parts;
  foreach my $clause (@{$self->{clauses_of}{$type}}) {
    next unless my $clause_expr = $args->{$clause};
    my $part = do {
      if (my $rdr = $self->{render_clause}{"${type}.${clause}"}) {
        $self->$rdr($clause, $clause_expr);
      } else {
        $self->join_query_parts(' ',
          $self->format_keyword($clause),
          $self->render_aqt($clause_expr, 1)
        );
      }
    };
    push @parts, $part;
  }
  my ($sql, @bind) = @{ $self->join_query_parts(' ', @parts) };
  return [
    (our $Render_Top_Level ? $sql : '('.$sql.')'),
    @bind
  ];
}

sub render_aqt {
  my ($self, $aqt, $top_level) = @_;
  local our $Render_Top_Level = $top_level;
  return $self->next::method($aqt);
}

sub render_statement {
  my ($self, $expr, $default_scalar_to) = @_;
  $self->render_aqt(
    $self->expand_expr($expr, $default_scalar_to), 1
  );
}

sub select {
  my ($self, @args) = @_;

  my $stmt = do {
    if (ref(my $sel = $args[0]) eq 'HASH') {
      $self->render_statement({ -select => $sel });
    } else {
      my %clauses;
      @clauses{qw(from select where order_by)} = @args;

      # This oddity is to literalify since historically SQLA doesn't quote
      # a single identifier argument, so we convert it into a literal

      $clauses{select} = { -literal => [ $clauses{select}||'*' ] }
        unless ref($clauses{select});
      \%clauses;
    }
  };

  my $rendered = $self->render_statement({ -select => $stmt });
  return wantarray ? @$rendered : $rendered->[0];
}

sub update {
  my ($self, $table, $set, $where, $options) = @_;

  return $self->render_statement({ -update => $_[1] }) if ref($_[1]) eq 'HASH';

  my %clauses;
  @clauses{qw(target set where)} = ($table, $set, $where);
  puke "Unsupported data type specified to \$sql->update"
    unless ref($clauses{set}) eq 'HASH';
  @clauses{keys %$options} = values %$options;
  return $self->render_statement({ -update => \%clauses });
}

sub delete {
  my ($self, $table, $where, $options) = @_;

  return $self->render_statement({ -delete => $_[1] }) if ref($_[1]) eq 'HASH';

  my %clauses = (target => $table, where => $where, %{$options||{}});
  return $self->render_statement({ -delete => \%clauses });
}

sub insert {
  my ($self, $table, $data, $options) = @_;

  return $self->render_statement({ -insert => $_[1] }) if ref($_[1]) eq 'HASH';

  my %clauses = (target => $table, values => $data, %{$options||{}});
  return $self->render_statement({ -insert => \%clauses });
}

sub _expand_insert_clause_target {
  +(target => $_[0]->_expand_maybe_list_expr($_[2], -ident));
}

sub _expand_insert_clause_fields {
  return +{ -row => [
    $_[0]->_expand_maybe_list_expr($_[2], -ident)
  ] } if ref($_[2]) eq 'ARRAY';
  return $_[2]; # should maybe still expand somewhat?
}

sub _expand_insert_clause_from {
  my ($self, undef, $data) = @_;
  if (ref($data) eq 'HASH' and (keys(%$data))[0] =~ /^-/) {
    return $self->expand_expr($data);
  }
  return $data if ref($data) eq 'HASH' and $data->{-row};
  my ($f_aqt, $v_aqt) = $self->_expand_insert_values($data);
  return (from => { -values => $v_aqt }, ($f_aqt ? (fields => $f_aqt) : ()));
}

sub _expand_insert_clause_returning {
  +(returning => $_[0]->_expand_maybe_list_expr($_[2], -ident));
}

sub _expand_values {
  my ($self, undef, $values) = @_;
  return { -values => [
    map +(
      ref($_) eq 'HASH'
        ? $self->expand_expr($_)
        : +{ -row => [ map $self->expand_expr($_), @$_ ] }
    ), ref($values) eq 'ARRAY' ? @$values : $values
  ] };
}

sub _render_values {
  my ($self, undef, $values) = @_;
  my $inner = [
    $self->join_query_parts(' ',
      $self->format_keyword('values'),
      $self->join_query_parts(', ',
        ref($values) eq 'ARRAY' ? @$values : $values
      ),
    ),
  ];
  return $self->join_query_parts('',
    (our $Render_Top_Level ? $inner : ('(', $inner, ')'))
  );
}

sub _ext_rw {
  my ($self, $name, $key, $value) = @_;
  return $self->{$name}{$key} unless @_ > 3;
  $self->{$name}{$key} = $value;
  return $self;
}

BEGIN {
  foreach my $type (qw(
    expand op_expand render op_render clause_expand clause_render
  )) {
    my $name = join '_', reverse split '_', $type;
    my $singular = "${type}er";
    eval qq{sub ${singular} { shift->_ext_rw($name => \@_) }; 1 }
      or die "Method builder failed for ${singular}: $@";
    eval qq{sub wrap_${singular} {
      my (\$self, \$key, \$builder) = \@_;
      my \$orig = \$self->_ext_rw('${name}', \$key);
      \$self->_ext_rw(
        '${name}', \$key,
        \$builder->(\$orig, '${name}', \$key)
      );
    }; 1 } or die "Method builder failed for wrap_${singular}: $@";
    eval qq{sub ${singular}s {
      my (\$self, \@args) = \@_;
      while (my (\$this_key, \$this_value) = splice(\@args, 0, 2)) {
        \$self->{${name}}{\$this_key} = \$this_value;
      }
      return \$self;
    }; 1 } or die "Method builder failed for ${singular}s: $@";
    eval qq{sub ${singular}_list { sort keys %{\$_[0]->{\$name}} }; 1; }
     or die "Method builder failed for ${singular}_list: $@";
  }
}

sub statement_list { sort keys %{$_[0]->{clauses_of}} }

sub clauses_of {
  my ($self, $of, @clauses) = @_;
  unless (@clauses) {
    return @{$self->{clauses_of}{$of}||[]};
  }
  if (ref($clauses[0]) eq 'CODE') {
    @clauses = $self->${\($clauses[0])}(@{$self->{clauses_of}{$of}||[]});
  }
  $self->{clauses_of}{$of} = \@clauses;
  return $self;
}

sub clone {
  my ($self) = @_;
  bless(
    {
      (map +($_ => (
        ref($self->{$_}) eq 'HASH'
          ? { %{$self->{$_}} }
          : $self->{$_}
      )), keys %$self),
    },
    ref($self)
  );
}

1;
