use strict;
use warnings FATAL => 'all';
use 5.006;

my %META = (
  name => 'SQL-Abstract',
  license => 'perl_5',
  dynamic_config => 0,
  prereqs => {
    configure => {
      requires => {
        'ExtUtils::MakeMaker'   => 0,
      }
    },
    build => {
      requires => {}
    },
    test => {
      requires => {
        'Test::More'      => '0.88',
        'Test::Exception' => '0.31',
        'Test::Warn'      => '0',
        'Storable'        => '0', # for cloning in tests
        'Data::Dumper::Concise' => '0',
      },
    },
    runtime => {
      requires => {
        'List::Util'     => '0',
        'Scalar::Util'   => '0',
        'Exporter'       => '5.57',
        'MRO::Compat'    => '0.12',
        'Moo'            => '2.000001',
        'Sub::Quote'     => '2.000001',
        'Hash::Merge'    => '0.12',
        'Text::Balanced' => '2.00',
        'perl'           => '5.006',
        # Used by SQL::Abstract::Test
        'Test::Deep'            => '0.101',
        'Test::Builder::Module' => '0.84',
      },
    },
    develop   => {
      requires => {
        'Test::Pod'           => '1.14',
        'Test::Pod::Coverage' => '1.04',
        'Pod::Coverage'       => '0.19',
        'Test::EOL'           => '1.0',
        'Test::NoTabs'        => '0.9',
      },
    },
  },
  resources => {
    repository => {
      url => 'https://github.com/dbsrgits/sql-abstract.git',
      web => 'https://github.com/dbsrgits/sql-abstract',
      type => 'git',
    },
    x_IRC => 'irc://irc.perl.org/#dbix-class',
    bugtracker => {
      web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=SQL-Abstract',
      mailto => 'bug-SQL-Abstract@rt.cpan.org',
    },
    license => [ 'http://dev.perl.org/licenses/' ],
  },
  no_index => {
    package => [ 'DBIx::Class::Storage::Debug::PrettyPrint' ],
    directory => [ 't', 'xt', 'examples' ],
  },
);

my %MM_ARGS = (
  test => { TESTS => 't/*.t t/*/*.t' },
);

## BOILERPLATE ###############################################################
require ExtUtils::MakeMaker;
(do './maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta        = $eumm_version >= 6.57_02;
my $mymeta_broken = $mymeta && $eumm_version < 6.57_07;

($MM_ARGS{NAME} = $META{name}) =~ s/-/::/g;
($MM_ARGS{VERSION_FROM} = "lib/$MM_ARGS{NAME}.pm") =~ s{::}{/}g;
$META{license} = [ $META{license} ]
  if $META{license} && !ref $META{license};
$MM_ARGS{LICENSE} = $META{license}[0]
  if $META{license} && $eumm_version >= 6.30;
$MM_ARGS{NO_MYMETA} = 1
  if $mymeta_broken;
$MM_ARGS{META_ADD} = { 'meta-spec' => { version => 2 }, %META }
  unless -f 'META.yml';

for (qw(configure build test runtime)) {
  my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
  my $r = $MM_ARGS{$key} = {
    %{$META{prereqs}{$_}{requires} || {}},
    %{delete $MM_ARGS{$key} || {}},
  };
  defined $r->{$_} or delete $r->{$_} for keys %$r;
}

$MM_ARGS{MIN_PERL_VERSION} = delete $MM_ARGS{PREREQ_PM}{perl} || 0;

delete $MM_ARGS{MIN_PERL_VERSION}
  if $eumm_version < 6.47_01;
$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
  if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
  if $eumm_version < 6.55_01;
delete $MM_ARGS{CONFIGURE_REQUIRES}
  if $eumm_version < 6.51_03;

ExtUtils::MakeMaker::WriteMakefile(%MM_ARGS);
## END BOILERPLATE ###########################################################
