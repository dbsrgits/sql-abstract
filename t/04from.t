#!/usr/bin/perl

use strict;
use warnings;
use Test::More;


plan tests => 4;

use SQL::Abstract;

my $sa = new SQL::Abstract;

my @j = (
    { child => 'person' },
    [ { father => 'person' }, { 'father.person_id' => 'child.father_id' }, ],
    [ { mother => 'person' }, { 'mother.person_id' => 'child.mother_id' } ],
);
my $match = 'person child JOIN person father ON ( father.person_id = '
          . 'child.father_id ) JOIN person mother ON ( mother.person_id '
          . '= child.mother_id )'
          ;
is( $sa->_recurse_from(@j), $match, 'join 1 ok' );

my @j2 = (
    { mother => 'person' },
    [   [   { child => 'person' },
            [   { father             => 'person' },
                { 'father.person_id' => 'child.father_id' }
            ]
        ],
        { 'mother.person_id' => 'child.mother_id' }
    ],
);
$match = 'person mother JOIN (person child JOIN person father ON ('
       . ' father.person_id = child.father_id )) ON ( mother.person_id = '
       . 'child.mother_id )'
       ;
is( $sa->_recurse_from(@j2), $match, 'join 2 ok' );

my @j3 = (
    { child => 'person' },
    [ { father => 'person', -join_type => 'inner' }, { 'father.person_id' => 'child.father_id' }, ],
    [ { mother => 'person', -join_type => 'inner'  }, { 'mother.person_id' => 'child.mother_id' } ],
);
$match = 'person child INNER JOIN person father ON ( father.person_id = '
          . 'child.father_id ) INNER JOIN person mother ON ( mother.person_id '
          . '= child.mother_id )'
          ;

is( $sa->_recurse_from(@j3), $match, 'join 3 (inner join) ok');

my @j4 = (
    { mother => 'person' },
    [   [   { child => 'person', -join_type => 'left' },
            [   { father             => 'person', -join_type => 'right' },
                { 'father.person_id' => 'child.father_id' }
            ]
        ],
        { 'mother.person_id' => 'child.mother_id' }
    ],
);
$match = 'person mother LEFT JOIN (person child RIGHT JOIN person father ON ('
       . ' father.person_id = child.father_id )) ON ( mother.person_id = '
       . 'child.mother_id )'
       ;
is( $sa->_recurse_from(@j4), $match, 'join 4 (nested joins + join types) ok');
