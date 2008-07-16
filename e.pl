use strict;
use warnings;

{
  package E;
  
  use overload
    '==' => '_op_num_eq',
    '>' => '_op_num_gt',
  ;
  
  sub new {
    my ($self, $data) = @_;
    my $class = ref($self) || $self;
    return bless(\$data, $class);
  };
  
  sub _op_num_eq { shift->_binop('==', @_) };
  sub _op_num_gt { shift->_binop('>', @_) };
  
  sub _binop {
    my ($self, $op, $rhs) = @_;
    $self->new([
      $op,
      ${$self},
      (ref $rhs ? ${$rhs} : [ -value, $rhs ]),
    ]);
  };
  
  package I;
  
  sub AUTOLOAD {
    our $AUTOLOAD =~ s/.*:://;
    return I::E->new([ -name, $AUTOLOAD ]);
  }

  sub DESTROY { }
  
  package I::E;
  
  our @ISA = qw(I E);
  
  1;
}

use Data::Dump qw(dump);
use Scalar::Util qw(blessed);

sub _une {
  my $un = shift;
  blessed($un) && $un->isa('E')
    ? ${$un}
    : ref($un) eq 'ARRAY'
      ? [ map { _une($_) } @$un ]
      : $un;
}

sub _run_e {
  local $_ = bless(\do { my $x }, 'I');
  map { _une($_) } $_[0]->();
}

sub expr (&) { _run_e(@_) }
sub _do {
  my ($name, $code, @in) = @_;
  [ $name, _run_e($code), @in ];
}
sub _dolist {
  my ($name, $code, @in) = @_;
  _do($name, sub { [ -list, map { _une($_) } $code->() ] }, @in);
}
sub ORDER_BY (&;@) { _do(-order_by, @_) }
sub SELECT (&;@) { _dolist('-select', @_); }
sub JOIN (&;@) { _do('-join', @_) }
sub WHERE (&;@) { _do(-where, @_) }
sub GROUP_BY (&;@) { _dolist(-group_by, @_); }
sub sum { E->new([ -sum, _une(shift) ]); }

#warn dump(expr { $_->one == $_->two });
warn dump(
  ORDER_BY { $_->aggregates->total }
    SELECT { $_->users->name, $_->aggregates->total }
      JOIN { $_->users->id == $_->aggregates->recipient_id }
        [ users => expr { $_->users } ],
        [ aggregates =>
            expr {
                SELECT { $_->recipient_id, [ total => sum($_->commission) ] }
                 WHERE { sum($_->commission) > 500 }
              GROUP_BY { $_->recipient_id }
                 WHERE { $_->entry_date > '2007-01-01' }
                  expr { $_->commissions }
            }
        ]
);
