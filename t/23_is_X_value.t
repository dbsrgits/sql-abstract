use warnings;
use strict;

use Test::More;
use Test::Exception;

use SQL::Abstract qw(is_plain_value is_literal_value);

{
  package # hideee
    SQLATest::SillyInt;

  use overload
    # *DELIBERATELY* unspecified
    #fallback => 1,
    '0+' => sub { ${$_[0]} },
  ;

  package # hideee
    SQLATest::SillyInt::Subclass;

  our @ISA = 'SQLATest::SillyInt';
}

{
  package # hideee
    SQLATest::SillierInt;

  use overload
    fallback => 0,
  ;

  package # hideee
    SQLATest::SillierInt::Subclass;

  use overload
    '0+' => sub { ${$_[0]} },
    '+' => sub { ${$_[0]} + $_[1] },
  ;

  our @ISA = 'SQLATest::SillierInt';
}

# make sure we recognize overloaded stuff properly
lives_ok {
  my $num = bless( \do { my $foo = 69 }, 'SQLATest::SillyInt::Subclass' );
  ok( is_plain_value $num, 'parent-fallback-provided stringification detected' );
  is("$num", 69, 'test overloaded object stringifies, without specified fallback');
} 'overload testing lives';

{
  my $nummifiable_maybefallback_num = bless( \do { my $foo = 42 }, 'SQLATest::SillierInt::Subclass' );
  lives_ok {
    ok( ( $nummifiable_maybefallback_num + 1) == 43 )
  };

  my $can_str = !! eval { "$nummifiable_maybefallback_num" };

  lives_ok {
    is_deeply(
      is_plain_value $nummifiable_maybefallback_num,
      ( $can_str ? [ 42 ] : undef ),
      'parent-disabled-fallback stringification detected same as perl',
    );
  };
}

is_deeply
  is_plain_value {  -value => [] },
  [ [] ],
  '-value recognized'
;

for ([], {}, \'') {
  is
    is_plain_value $_,
    undef,
    'nonvalues correctly recognized'
  ;
}

for (undef, { -value => undef }) {
  is_deeply
    is_plain_value $_,
    [ undef ],
    'NULL -value recognized'
  ;
}

is_deeply
  is_literal_value { -ident => 'foo' },
  [ 'foo' ],
  '-ident recognized as literal'
;

is_deeply
  is_literal_value \[ 'sql', 'bind1', [ {} => 'bind2' ] ],
  [ 'sql', 'bind1', [ {} => 'bind2' ] ],
  'literal correctly unpacked'
;


for ([], {}, \'', undef) {
  is
    is_literal_value { -ident => $_ },
    undef,
    'illegal -ident does not trip up detection'
  ;
}

done_testing;
