use strict;
use warnings;

use vars qw($TESTING);
$TESTING = 1;
use Test::More;

# use a BEGIN block so we print our plan before SQL::Abstract is loaded
BEGIN { plan tests => 7 }

use SQL::Abstract;

my $sql_maker = SQL::Abstract->new;

$sql_maker->{quote_char} = '`';
$sql_maker->{name_sep} = '.';

my ($sql,) = $sql_maker->select(
          [
            {
              'me' => 'cd'
            },
            [
              {
                'artist' => 'artist',
                '-join_type' => ''
              },
              {
                'artist.artistid' => 'me.artist'
              }
            ]
          ],
          [
            #{
            #  'count' => '*'
            #}
            \'COUNT( * )'
          ],
          {
            'artist.name' => 'Caterwauler McCrae',
            'me.year' => 2001
          },
          [],
          undef,
          undef
);

is($sql, 
   q/SELECT COUNT( * ) FROM `cd` `me`  JOIN `artist` `artist` ON ( `artist`.`artistid` = `me`.`artist` ) WHERE ( `artist`.`name` = ? AND `me`.`year` = ? )/, 
   'got correct SQL for count query with quoting');


($sql,) = $sql_maker->select(
      [
        {
          'me' => 'cd'
        }
      ],
      [
        'me.cdid',
        'me.artist',
        'me.title',
        'me.year'
      ],
      undef,
      [
        { -desc => 'year' }
      ],
      undef,
      undef
);




is($sql, 
   q/SELECT `me`.`cdid`, `me`.`artist`, `me`.`title`, `me`.`year` FROM `cd` `me` ORDER BY `year` DESC/, 
   'quoted ORDER BY with DESC okay');


($sql,) = $sql_maker->select(
      [
        {
          'me' => 'cd'
        }
      ],
      [
        'me.*'
      ],
      undef,
      [],
      undef,
      undef    
);

is($sql, q/SELECT `me`.* FROM `cd` `me`/, 'select attr with me.* is right');

($sql,) = $sql_maker->select(
          [
            {
              'me' => 'cd'
            }
          ],
          [
            'me.cdid',
            'me.artist',
            'me.title',
            'me.year'
          ],
          undef,
          [
            \'year DESC'
          ],
          undef,
          undef
);

is($sql, 
   q/SELECT `me`.`cdid`, `me`.`artist`, `me`.`title`, `me`.`year` FROM `cd` `me` ORDER BY year DESC/,
   'did not quote ORDER BY with scalarref');

my %data = ( 
    name => 'Bill',
    order => 12
);

my @binds;

($sql,@binds) = $sql_maker->update(
          'group',
          {
            'order' => '12',
            'name' => 'Bill'
          }
);

is($sql,
   q/UPDATE `group` SET `name` = ?, `order` = ?/,
   'quoted table names for UPDATE');

$sql_maker->{quote_char} = [qw/[ ]/];

($sql,) = $sql_maker->select(
          [
            {
              'me' => 'cd'
            },
            [
              {
                'artist' => 'artist',
                '-join_type' => ''
              },
              {
                'artist.artistid' => 'me.artist'
              }
            ]
          ],
          [
            #{
            #  'count' => '*'
            #}
            \'COUNT( * )'
          ],
          {
            'artist.name' => 'Caterwauler McCrae',
            'me.year' => 2001
          },
          [],
          undef,
          undef
);

is($sql,
   q/SELECT COUNT( * ) FROM [cd] [me]  JOIN [artist] [artist] ON ( [artist].[artistid] = [me].[artist] ) WHERE ( [artist].[name] = ? AND [me].[year] = ? )/,
   'got correct SQL for count query with bracket quoting');


($sql,@binds) = $sql_maker->update(
          'group',
          {
            'order' => '12',
            'name' => 'Bill'
          }
);

is($sql,
   q/UPDATE [group] SET [name] = ?, [order] = ?/,
   'bracket quoted table names for UPDATE');
