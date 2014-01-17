use inc::Module::Install 1.06;
use strict;
use warnings;

use 5.006002;

##
## TEMPORARY (and non-portable)
## Get the dq stuff
##
my $target_libdir;
BEGIN {
  $target_libdir = 'lib/SQL/Abstract/_TempExtlib';

  if ($Module::Install::AUTHOR or $ENV{TRAVIS}) {

    `rm -rf $target_libdir`;
    `mkdir $target_libdir`;
    for (
      [ 'Data-Query' => 'master' ],
    ) {
      my $tdir = "/tmp/dqlib/$_->[0]/";

      `rm -rf $tdir`;

      `GIT_SSH=maint/careless_ssh.bash git clone --bare --quiet --branch=$_->[1] --depth=1 git://git.shadowcat.co.uk/dbsrgits/$_->[0] $tdir`;
      printf "\nIncluding %s git rev %s\n",
        $_->[0],
        scalar `GIT_DIR=$tdir git rev-parse $_->[1]`,
      ;
      `git archive --format=tar --remote=file://$tdir $_->[1] lib/ | tar --strip-components=1 -xC $target_libdir`;

      #`rm -rf $tdir`;
    }
  }
}

use lib $target_libdir;


perl_version '5.006002';
name 'SQL-Abstract';
author 'Nathan Wiger <nate@wiger.org>';
resources 'license'     => 'http://dev.perl.org/licenses/';
resources 'repository'  => 'git://git.shadowcat.co.uk/dbsrgits/SQL-Abstract.git';
resources 'bugtracker'  => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Abstract';

all_from 'lib/SQL/Abstract.pm';

dynamic_config 0;

# deps for Data::Query
requires 'SQL::ReservedWords' => '0.8',
requires 'Safe::Isa' => '1.000003',

requires 'List::Util'   => 0;
requires 'Scalar::Util' => 0;
requires 'Getopt::Long::Descriptive' => 0.091;
requires 'Hash::Merge' => 0.12;
requires 'Moo' => '0.009014';
requires 'namespace::clean' => '0.24';

test_requires "Test::More"      => 0.92;
test_requires "Test::Exception" => 0;
test_requires "Test::Warn"      => 0;
test_requires "Test::Deep"      => '0.101';
test_requires "Storable"        => 0;   # for cloning in tests

no_index package => 'DBIx::Class::Storage::Debug::PrettyPrint';
no_index directory => 'examples';
no_index package => 'SQL::Abstract::_TempExtlib';
no_index directory => 'lib/SQL/Abstract/_TempExtlib';

install_script 'format-sql';

tests_recursive 't';

auto_install();

WriteAll();
