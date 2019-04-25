package with;

# This must be its own dist later

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
use mro;

my $comp = 'A001';

sub components {
  my ($inv, @comp) = @_;
  my $class = ref($inv) || $inv;
  my $new_class = join('::', $class, $comp++);
  require Class::C3::Componentised;
  my @comp_classes = map +(/^\+(.+)$/ ? "${class}::$1" : $_), @comp;
  Class::C3::Componentised->ensure_class_loaded($_) for @comp_classes;
  Class::C3::Componentised->inject_base(
    $new_class,
    @comp_classes, $class
  );
  mro::set_mro($new_class, 'c3');
  return $new_class unless ref($inv);
  return bless($inv, $new_class);
}

sub roles {
  my ($inv, @roles) = @_;
  my $class = ref($inv) || $inv;
  require Role::Tiny;
  my $new_class = Role::Tiny->create_class_with_roles($class,
    map +(/^\+(.+)$/ ? "${class}::$1" : $_), @roles
  );
  return $new_class unless ref($inv);
  return bless($inv, $new_class);
}

1;
