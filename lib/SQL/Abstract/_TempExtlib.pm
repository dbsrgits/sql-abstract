package # hide from the pauses
  SQL::Abstract::_TempExtlib;

use strict;
use warnings;
use File::Spec;

our ($HERE) = File::Spec->rel2abs(
  File::Spec->catdir( (File::Spec->splitpath(__FILE__))[1], '_TempExtlib' )
) =~ /^(.*)$/; # screw you, taint mode

unshift @INC, $HERE;

1;
