use SQL::Abstract2;

my $bind_vars = [];
my $q = SQL::Abstract2->new;

my $test_struct =
  [ -order_by =>
    [-asc => [-name => 'field3']],
    [ -group_by =>
      [ -name => 'field4' ],
      [-select =>
       [-list =>
        [-name => qw/table1 field1/],
        [-name => qw/table1 field2/],
        [-name => qw/table2 field3/],
       ],
       [ -where => [-and => [-and => ( ['<' => ( [-name => qw/table1 field1/],
                                                 [-date_sub => ['-curr_date'], qw/15 DAY/]
                                               ),
                                       ],
                                       ['!=' => [-name => 'field3'], [-value => undef] ],
                                       ['='  => [-name => 'field4'], [-value => 500]   ],
                                     ),
                            ],
                    [-or => ( [-in => [-name => 'field5'], [-value => 100], [-value => 100]],
                              [-between => [-name => 'field6'], [-value => 12], [-value => 26]]
                            ),
                    ],
                   ],
         [-from => ( [-name => 'schema', 'table1'],
                     [-alias => [-name => 'schema', 'table1'], 'table2'] ,
                     ['-left join' =>
                      [-alias => [-name => 'schema', 'table2',], 'table3'],
                      [-on => [ -and => ( ['=', ( [-name => 'table1', 'fielda'],
                                                  [-name => 'table2', 'fielda'] ) ],
                                          ['=', ( [-name => 'table1', 'fielda'],
                                                  [-name => 'table2', 'fielda'] ) ],
                                        ),
                              ],
                    ],
                     ],
                   )
         ],
         
       ],
      ],
    ],
  ];
#    [-'limit' => [-value => 30],  [-value => 100]],
print $q->handle_op($test_struct);
