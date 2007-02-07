use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SQL::Abstract',
    VERSION_FROM      => 'lib/SQL/Abstract.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM  => 'lib/SQL/Abstract.pm', # retrieve abstract from module
    AUTHOR         => 'Nathan Wiger (nate@wiger.org)',
);
