use inc::Module::Install 1.0;
use strict;
use warnings;

use 5.006002;

perl_version '5.006002';
name 'SQL-Abstract';
author 'Nathan Wiger <nate@wiger.org>';

all_from 'lib/SQL/Abstract.pm';

requires 'List::Util'   => 0;
requires 'Scalar::Util' => 0;
requires 'Class::Accessor::Grouped' => 0.09005;
requires 'Getopt::Long::Descriptive' => 0.086;
requires 'Hash::Merge' => 0.12;

test_requires "Test::More"      => 0.92;
test_requires "Test::Deep"      => 0.106;
test_requires "Test::Exception" => 0;
test_requires "Test::Warn"      => 0;
test_requires "Storable"        => 0;   # for cloning in tests

no_index package => 'DBIx::Class::Storage::Debug::PrettyPrint';
no_index directory => 'examples';

install_script 'format-sql';

tests_recursive 't';

WriteAll();
