package SQL::Abstract::Parts;

use Module::Runtime ();
use Scalar::Util ();
use strict;
use warnings;

use overload '""' => 'stringify', fallback => 1;

sub new {
  my ($proto, $join, @parts) = @_;
  bless([
    $join, map Scalar::Util::blessed($_) ? [ @$_ ] : $_, @parts
  ], ref($proto) || $proto);
}

sub stringify {
  my ($self) = @_;
  my ($join, @parts) = @$self;
  return join $join, map ref() ? stringify($_) : $_, @parts;
}

sub to_array { return @{$_[0]} }

sub format {
  my ($self, %opts) = @_;
  Module::Runtime::use_module('SQL::Abstract::Formatter')
    ->new(%opts)
    ->format($self->to_array);
}

1;
