package SQL::Abstract2;

use Moose;
has known_ops => (is => 'rw', isa => 'HashRef', lazy_build => 1);
has use_value_placeholders =>
  (
   is => 'rw',
   isa => 'Bool',
   required => 1,
   default => 1
  );
has value_placeholder_char =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {"?"},
  );
has value_quote_char =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {"'"},
  );

has name_quote_char =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {'`'},
  );

has name_separator =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {'.'},
  );

has logical_group_open_char =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {'('},
  );

has logical_group_close_char =>
  (
   is => 'rw',
   isa => 'Str',
   required => 1,
   default => sub {')'},
  );


sub _build_known_ops {
  my %known =
    (
     'in' => {handler => 'handle_op_in'},
     'date_add' => {handler => 'handle_op_date_add_sub'},
     'date_sub' => {handler => 'handle_op_date_add_sub'},
     'and' => {handler => 'handle_op_grouping'},
     'xor' => {handler => 'handle_op_grouping'},
     'or'  => {handler => 'handle_op_grouping'},
     'name'  => {handler => 'handle_op_name', args_min => 1},
     'between' => {
                   handler => 'handle_op_between',
                   args_min => 3,
                   args_max => 3,
                  },
     'value' => {
                 handler => 'handle_op_value',
                 args_min => 1,
                 args_max => 1
                },
     'asc' => {
                 handler => 'handle_op_asc_desc',
                 args_min => 1,
                 args_max => 1
                },
     'desc' => {
                 handler => 'handle_op_asc_desc',
                 args_min => 1,
                 args_max => 1
                },
     '=' => {
             args_min => 2,
             args_max => 2,
             handler => 'handle_op_null_aware_equality',
            },
     '!=' => {
              args_min => 2,
              args_max => 2,
              handler => 'handle_op_null_aware_equality',
             },
     'is' => {
              args_min => 2,
              args_max => 2,
              handler => 'handle_op_is',
             },
     'where' => {
                 args_min => 1,
                 args_max => 1,
                 handler => 'handle_op_sql_word_and_args'
                },
    );

  foreach my $bin_op (qw^ > < >= <= + - * / % <> <=> ^) {
    $known{$bin_op} = {
                       args_min => 2,
                       args_max => 2,
                       handler => 'simple_binary_op',
                      };
  }
  for my $word ('fields', 'from', 'order by', 'group by'){
    $known{$word} = { handler => 'handle_op_sql_word_and_list' };
  }
  for my $word (qw/insert update select delete having/, 'replace into'){
    $known{$word} = { handler => 'handle_op_sql_word_and_args' };
  }
  for my $join ('join','left join','right join','inner join', 'cross join',
                'straight_join','left outer join','right outer join',
                'natural join', 'natural left join', 'natural left outer join',
                'straight join', 'natural right join', 'natural right outer join',
               ){
    $known{$join} = { handler => 'handle_op_join' };
  }
  return \%known;
}

sub handle_op_asc_desc {
  my($self, $op, $args, $bind_vars) = @_;
  return join(' ', $self->handle_op($args->[0], $bind_vars), uc($op));
}

sub handle_op_limit {
  my($self, $op, $args, $bind_vars) = @_;
  return $self->handle_op_sql_word_and_list('LIMIT', $args, $bind_vars)
}

sub handle_op_join {
  my($self, $op, $args, $bind_vars) = @_;
  my @args = @$args;
  my $join_type = uc $op;
  my $table = $self->handle_op( shift(@args), $bind_vars);
  if(@args){
    return join(" ", $join_type, $table, $self->handle_op(shift(@args), $bind_vars))
  } else {
    join(" ", $join_type, $table);
  }
}

sub handle_op_sql_list {
  my($self, $op, $args, $bind_vars) = @_;
  my @quoted_args = map{ $self->handle_op($_, $bind_vars) } @$args;
  return join ', ', @quoted_args;
}

sub handle_op_sql_word_and_list {
  my($self, $op, $args, $bind_vars) = @_;
  return join ' ', uc($op), $self->handle_op_sql_list($op, $args, $bind_vars); 
}

sub handle_op_sql_word_and_args {
  my($self, $op, $args, $bind_vars) = @_;
  return join ' ', uc($op), map { $self->handle_op($_, $bind_vars) } @$args; 
}

sub handle_op_grouping {
  my($self, $op, $args, $bind_vars) = @_;
  my $sep = uc $op;
  my @pieces = map { $self->handle_op($_, $bind_vars) } @$args;
  if(@pieces > 1){
    return join("",
                $self->logical_group_open_char,
                (join " ${sep} ", @pieces),
                $self->logical_group_close_char,
               );
  }
  return shift @pieces;
}

sub handle_op_null_aware_equality {
  my($self, $op, $args, $bind_vars) = @_;

  my($name, $value);
  if ($args->[0]->[0] eq '-name' && $args->[1]->[0] eq '-value') {
    ($name, $value) = @{$args}[0,1];
  } elsif ($args->[1]->[0] eq '-name' && $args->[0]->[0] eq '-value') {
    ($name, $value) = @{$args}[1,0];
  }
  if (defined($value) && !defined($value->[1])) {
    my $is_op = $op eq '=' ? 'is' : 'is not';
    return $self->handle_op_is($is_op, [$name, $value], $bind_vars);
  }
  return $self->simple_binary_op($op, $args, $bind_vars);
}

sub handle_op_date_add_sub {
 my($self, $op, $args, $bind_vars) = @_;
  if ($op =~ /add/i) {
    $op = 'DATE_ADD';
  } elsif ($op =~ /sub/i) {
    $op = 'DATE_SUB';
  }
  my($date, $interval, $measure) = @$args;
  $date = $self->maybe_quote_value($date, $bind_vars);
  return "${op}($date, INTERVAL $interval $measure)";
}

sub handle_op_between {
  my($self, $op, $args, $bind_vars) = @_;
  my @args = @$args; #these are here so we don't destroy the refs given to us
  my $left_side = $self->handle_op(shift(@args), $bind_vars);
  my $sql = $op =~ /not(?:_|\w*)between/i ? 'NOT BETWEEN' : 'BETWEEN';
  return join ' ', $left_side, $sql, $self->simple_binary_op('AND', \@args, $bind_vars);
}

sub handle_op_in {
  my($self, $op, $args, $bind_vars) = @_;
  my @args = @$args;
  my $left_side = $self->handle_op(shift(@args), $bind_vars);
  my $sql = $op =~ /not(?:_|\w*)in/i ? 'NOT IN' : 'IN';
  return join(" ", $left_side, $self->simple_function_op($sql, \@args, $bind_vars));
}

sub handle_op_is {
  my($self, $op, $args, $bind_vars) = @_;
  my $sql = $op =~ /is(?:_|\w*)not/i ? 'IS NOT' : 'IS';
  return $self->simple_binary_op($sql, $args, $bind_vars);
}

sub simple_binary_op {
  my($self, $op, $args, $bind_vars) = @_;
  $op = uc $op;
  my @arg_strs =  map{ $self->handle_op($_, $bind_vars) } @$args;
  return join(" ${op} ", @arg_strs);
}

sub simple_function_op {
  my($self, $op, $args, $bind_vars) = @_;
  my $arg_str = $self->handle_op_sql_list($op, $args, $bind_vars);
  my $function = uc $op;
  return "${function}(${arg_str})";
}

sub handle_op_value {
  my ($self, $op, $args, $bind_vars) = @_;
  return $self->maybe_quote_value($args->[0], $bind_vars);
}
sub handle_op_name {
  my ($self, $op, $args, $bind_vars) = @_;
  return $self->maybe_quote_name(@$args);
}

sub handle_op {
  my ($self, $frame, $bind_vars) = @_;
  use Data::Dumper;
  confess( Dumper($frame) ) unless ref $frame;
  my ($needle, $op, $args);
  ($op, @$args) = @$frame;

  if ($op =~/^-((?:not\s*)?(.+?))$/) {
    #bye bye leadin / trailing whitespace, keep needle lc for simplicity
    $op = $1;
    $needle = lc $2;
    ($op) = ($op =~ /^\s*(.+?)\s*$/);
    ($needle) = ($needle =~ /^\s*(.+?)\s*$/);
  }
  my $op_info;
  if ( exists $self->known_ops->{$op} ) {
    $op_info = $self->known_ops->{$op};
  } elsif(defined $needle) {
    if ( exists $self->known_ops->{$needle} ) {
      $op_info = $self->known_ops->{$needle};
    } elsif ( ($needle =~ /^\w+$/) && (my $coderef = $self->can("handle_op_${needle}"))) {
      return $self->$coderef($op, $args, $bind_vars)
    } else {
      return $self->simple_function_op($op, $args, $bind_vars);
    }
  } else {
    use Data::Dumper;
    print Dumper $op;
    die("Failed to find handle '${op}'");
  }

  #arg checking
  if (exists $op_info->{args_min}) {
    my $min = $op_info->{args_min};
    die("Operator ${op} needs a minimum of ${min} arguments")
      unless $min <= @$args;
  }
  if (exists $op_info->{args_max}) {
    my $max = $op_info->{args_max};
    die("Operator ${op} can only have up to ${max} arguments")
     unless $max >= @$args;
  }

  my $handler = $op_info->{handler};
  if ( ref($handler) eq 'CODE' ) {
    return $handler->($op, $args, $bind_vars);
  } elsif (my $coderef = $self->can($handler)) {
    $self->$coderef($op, $args, $bind_vars);
  } else {
    die("can not use handler ${handler}");
  }
}

sub maybe_quote_value{
  my($self, $value, $bind_vars) = @_;
  return $$value if ref($value) eq 'SCALAR';
  if ( $self->use_value_placeholders ){
    push @$bind_vars, $value;
    return $self->value_placeholder_char;
  }
  return 'NULL' unless defined $value;
  return $value if Scalar::Util::looks_like_number( $value );
  my $q = $self->value_quote_char;
  return join "", $q, $value, $q;
}

sub maybe_quote_name{
  my($self, @parts) = @_;
  my $q = $self->name_quote_char;
  my $as;
  if(ref($parts[-1]) eq 'ARRAY' && $parts[-1]->[0] eq '-as'){
    $as = pop(@parts)->[1];
    $as = ref($as) eq 'SCALAR' ? $$as : join("", $q, $as, $q);
  }
  @parts = map { ref($_) eq 'SCALAR' ? $$_ : join("", $q, $_, $q) } @parts;
  my $name = join($self->name_separator, @parts);
  return join ' AS ', grep { defined } ($name, $as); #XXX make 'AS' an attribute
}

__PACKAGE__->meta->make_immutable;

1;

__END__;
