use inc::Module::Install 0.79;
use strict;
use warnings;

use 5.006002;

perl_version '5.006002';
name 'SQL-Abstract';
author 'Nathan Wiger <nate@wiger.org>';

all_from 'lib/SQL/Abstract.pm';

requires 'List::Util'   => 0;
requires 'Scalar::Util' => 0;

test_requires "Test::More"      => 0;
test_requires "Test::Exception" => 0;
test_requires "Test::Warn"      => 0;
test_requires "Storable"        => 0;   # for cloning in tests

tests_recursive 't';

WriteAll();
