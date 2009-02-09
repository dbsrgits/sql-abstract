use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME           => 'SQL::Abstract',
    VERSION_FROM   => 'lib/SQL/Abstract.pm', # finds $VERSION
    PREREQ_PM      => {
      "List::Util" => 0,
      "Scalar::Util" => 0,
      "Test::Builder" => 0,
      "Test::More" => 0,
      "Test::Exception" => 0,
      "Test::Warn" => 0,
      "Test::Deep" => 0,
      "Data::Dumper" => 0,
     }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM  => 'lib/SQL/Abstract.pm', # retrieve abstract from module
    AUTHOR         => 'Matt Trout <mst@shadowcat.co.uk>, but see the POD',
);
