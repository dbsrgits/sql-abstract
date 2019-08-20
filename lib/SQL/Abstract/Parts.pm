package SQL::Abstract::Parts;

use strict;
use warnings;

use overload '""' => 'stringify', fallback => 1;

sub new {
  my ($proto, @args) = @_;
  bless(\@args, ref($proto) || $proto);
}

sub stringify {
  my ($self) = @_;
  my ($join, @parts) = @$self;
  return join $join, @parts;
}

1;
