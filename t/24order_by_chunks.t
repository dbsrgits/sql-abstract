use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper::Concise;

use SQL::Abstract;

use SQL::Abstract::Test import => ['is_same_sql_bind'];
my @cases = (
  [
    undef,
    [
      \"colA DESC"
    ],
    [
      "colA DESC"
    ]
  ],
  [
    "`",
    [
      \"colA DESC"
    ],
    [
      "colA DESC"
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    undef,
    [
      "colA DESC"
    ],
    [
      "colA DESC"
    ]
  ],
  [
    "`",
    [
      "colA DESC"
    ],
    [
      "`colA DESC`"
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "colA",
      "colB"
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "`colA`",
      "`colB`"
    ]
  ],
  [
    undef,
    [
      "colA ASC"
    ],
    [
      "colA ASC"
    ]
  ],
  [
    undef,
    [
      "colB DESC"
    ],
    [
      "colB DESC"
    ]
  ],
  [
    undef,
    [
      [
        "colA ASC",
        "colB DESC"
      ]
    ],
    [
      "colA ASC",
      "colB DESC"
    ]
  ],
  [
    "`",
    [
      "colA ASC"
    ],
    [
      "`colA ASC`"
    ]
  ],
  [
    "`",
    [
      "colB DESC"
    ],
    [
      "`colB DESC`"
    ]
  ],
  [
    "`",
    [
      [
        "colA ASC",
        "colB DESC"
      ]
    ],
    [
      "`colA ASC`",
      "`colB DESC`"
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "colA ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "`colA` ASC"
      ]
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "colB DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "colA ASC"
      ]
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-asc" => "colA"
        },
        {
          "-desc" => "colB"
        }
      ]
    ],
    [
      [
        "colA ASC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "`colA` ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-asc" => "colA"
        },
        {
          "-desc" => "colB"
        }
      ]
    ],
    [
      [
        "`colA` ASC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        {
          "-desc" => "colB"
        }
      ]
    ],
    [
      "colA",
      [
        "colB DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => "colB"
      }
    ],
    [
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        {
          "-desc" => "colB"
        }
      ]
    ],
    [
      "`colA`",
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "colA",
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        }
      ]
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "`colA`",
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        }
      ]
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "colA",
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colC"
    ],
    [
      "colC"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => "colC"
      }
    ],
    [
      [
        "colC ASC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-asc" => "colC"
        }
      ]
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ],
      [
        "colC ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "`colA`",
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colC"
    ],
    [
      "`colC`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => "colC"
      }
    ],
    [
      [
        "`colC` ASC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-asc" => "colC"
        }
      ]
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ],
      [
        "`colC` ASC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "colA",
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colC"
    ],
    [
      "colC"
    ]
  ],
  [
    undef,
    [
      "colD"
    ],
    [
      "colD"
    ]
  ],
  [
    undef,
    [
      [
        "colC",
        "colD"
      ]
    ],
    [
      "colC",
      "colD"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => [
          "colC",
          "colD"
        ]
      }
    ],
    [
      [
        "colC ASC"
      ],
      [
        "colD ASC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-asc" => [
            "colC",
            "colD"
          ]
        }
      ]
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ],
      [
        "colC ASC"
      ],
      [
        "colD ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "`colA`",
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colC"
    ],
    [
      "`colC`"
    ]
  ],
  [
    "`",
    [
      "colD"
    ],
    [
      "`colD`"
    ]
  ],
  [
    "`",
    [
      [
        "colC",
        "colD"
      ]
    ],
    [
      "`colC`",
      "`colD`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => [
          "colC",
          "colD"
        ]
      }
    ],
    [
      [
        "`colC` ASC"
      ],
      [
        "`colD` ASC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-asc" => [
            "colC",
            "colD"
          ]
        }
      ]
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ],
      [
        "`colC` ASC"
      ],
      [
        "`colD` ASC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "colA",
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colC"
    ],
    [
      "colC"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => "colC"
      }
    ],
    [
      [
        "colC DESC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-desc" => "colC"
        }
      ]
    ],
    [
      [
        "colA DESC"
      ],
      [
        "colB DESC"
      ],
      [
        "colC DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colA",
        "colB"
      ]
    ],
    [
      "`colA`",
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => [
          "colA",
          "colB"
        ]
      }
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colC"
    ],
    [
      "`colC`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => "colC"
      }
    ],
    [
      [
        "`colC` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-desc" => [
            "colA",
            "colB"
          ]
        },
        {
          "-desc" => "colC"
        }
      ]
    ],
    [
      [
        "`colA` DESC"
      ],
      [
        "`colB` DESC"
      ],
      [
        "`colC` DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colA"
    ],
    [
      "colA"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "colA ASC"
      ]
    ]
  ],
  [
    undef,
    [
      "colB"
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      [
        "colB"
      ]
    ],
    [
      "colB"
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => [
          "colB"
        ]
      }
    ],
    [
      [
        "colB DESC"
      ]
    ]
  ],
  [
    undef,
    [
      "colC"
    ],
    [
      "colC"
    ]
  ],
  [
    undef,
    [
      "colD"
    ],
    [
      "colD"
    ]
  ],
  [
    undef,
    [
      [
        "colC",
        "colD"
      ]
    ],
    [
      "colC",
      "colD"
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => [
          "colC",
          "colD"
        ]
      }
    ],
    [
      [
        "colC ASC"
      ],
      [
        "colD ASC"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-asc" => "colA"
        },
        {
          "-desc" => [
            "colB"
          ]
        },
        {
          "-asc" => [
            "colC",
            "colD"
          ]
        }
      ]
    ],
    [
      [
        "colA ASC"
      ],
      [
        "colB DESC"
      ],
      [
        "colC ASC"
      ],
      [
        "colD ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colA"
    ],
    [
      "`colA`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => "colA"
      }
    ],
    [
      [
        "`colA` ASC"
      ]
    ]
  ],
  [
    "`",
    [
      "colB"
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      [
        "colB"
      ]
    ],
    [
      "`colB`"
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => [
          "colB"
        ]
      }
    ],
    [
      [
        "`colB` DESC"
      ]
    ]
  ],
  [
    "`",
    [
      "colC"
    ],
    [
      "`colC`"
    ]
  ],
  [
    "`",
    [
      "colD"
    ],
    [
      "`colD`"
    ]
  ],
  [
    "`",
    [
      [
        "colC",
        "colD"
      ]
    ],
    [
      "`colC`",
      "`colD`"
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => [
          "colC",
          "colD"
        ]
      }
    ],
    [
      [
        "`colC` ASC"
      ],
      [
        "`colD` ASC"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-asc" => "colA"
        },
        {
          "-desc" => [
            "colB"
          ]
        },
        {
          "-asc" => [
            "colC",
            "colD"
          ]
        }
      ]
    ],
    [
      [
        "`colA` ASC"
      ],
      [
        "`colB` DESC"
      ],
      [
        "`colC` ASC"
      ],
      [
        "`colD` ASC"
      ]
    ]
  ],
  [
    undef,
    [
      \[
          "colA LIKE ?",
          "test"
        ]
    ],
    [
      [
        "colA LIKE ?",
        "test"
      ]
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => \[
            "colA LIKE ?",
            "test"
          ]
      }
    ],
    [
      [
        "colA LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    "`",
    [
      \[
          "colA LIKE ?",
          "test"
        ]
    ],
    [
      [
        "colA LIKE ?",
        "test"
      ]
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => \[
            "colA LIKE ?",
            "test"
          ]
      }
    ],
    [
      [
        "colA LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    undef,
    [
      \[
          "colA LIKE ? DESC",
          "test"
        ]
    ],
    [
      [
        "colA LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    "`",
    [
      \[
          "colA LIKE ? DESC",
          "test"
        ]
    ],
    [
      [
        "colA LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    undef,
    [
      \[
          "colA"
        ]
    ],
    [
      [
        "colA"
      ]
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => \[
            "colA"
          ]
      }
    ],
    [
      [
        "colA ASC"
      ]
    ]
  ],
  [
    undef,
    [
      \[
          "colB LIKE ?",
          "test"
        ]
    ],
    [
      [
        "colB LIKE ?",
        "test"
      ]
    ]
  ],
  [
    undef,
    [
      {
        "-desc" => \[
            "colB LIKE ?",
            "test"
          ]
      }
    ],
    [
      [
        "colB LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    undef,
    [
      \[
          "colC LIKE ?",
          "tost"
        ]
    ],
    [
      [
        "colC LIKE ?",
        "tost"
      ]
    ]
  ],
  [
    undef,
    [
      {
        "-asc" => \[
            "colC LIKE ?",
            "tost"
          ]
      }
    ],
    [
      [
        "colC LIKE ? ASC",
        "tost"
      ]
    ]
  ],
  [
    undef,
    [
      [
        {
          "-asc" => \[
              "colA"
            ]
        },
        {
          "-desc" => \[
              "colB LIKE ?",
              "test"
            ]
        },
        {
          "-asc" => \[
              "colC LIKE ?",
              "tost"
            ]
        }
      ]
    ],
    [
      [
        "colA ASC"
      ],
      [
        "colB LIKE ? DESC",
        "test"
      ],
      [
        "colC LIKE ? ASC",
        "tost"
      ]
    ]
  ],
  [
    "`",
    [
      \[
          "colA"
        ]
    ],
    [
      [
        "colA"
      ]
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => \[
            "colA"
          ]
      }
    ],
    [
      [
        "colA ASC"
      ]
    ]
  ],
  [
    "`",
    [
      \[
          "colB LIKE ?",
          "test"
        ]
    ],
    [
      [
        "colB LIKE ?",
        "test"
      ]
    ]
  ],
  [
    "`",
    [
      {
        "-desc" => \[
            "colB LIKE ?",
            "test"
          ]
      }
    ],
    [
      [
        "colB LIKE ? DESC",
        "test"
      ]
    ]
  ],
  [
    "`",
    [
      \[
          "colC LIKE ?",
          "tost"
        ]
    ],
    [
      [
        "colC LIKE ?",
        "tost"
      ]
    ]
  ],
  [
    "`",
    [
      {
        "-asc" => \[
            "colC LIKE ?",
            "tost"
          ]
      }
    ],
    [
      [
        "colC LIKE ? ASC",
        "tost"
      ]
    ]
  ],
  [
    "`",
    [
      [
        {
          "-asc" => \[
              "colA"
            ]
        },
        {
          "-desc" => \[
              "colB LIKE ?",
              "test"
            ]
        },
        {
          "-asc" => \[
              "colC LIKE ?",
              "tost"
            ]
        }
      ]
    ],
    [
      [
        "colA ASC"
      ],
      [
        "colB LIKE ? DESC",
        "test"
      ],
      [
        "colC LIKE ? ASC",
        "tost"
      ]
    ],
  ],
  [
    undef,
    [{}],
    [],
  ],
);

for my $case (@cases) {
  my ($quote, $expr, $out) = @$case;
  my $sqla = SQL::Abstract->new({ quote_char => $quote });

  if (
    @$expr == 1
    and ref($expr->[0]) eq 'REF'
    and ref(${$expr->[0]}) eq 'ARRAY'
    and @${$expr->[0]} == 1
  ) {
    # \[ 'foo' ] is exactly equivalent to \'foo' and the new code knows that
    $out = $out->[0];
  }

  my @chunks = $sqla->_order_by_chunks($expr);

  unless (is(Dumper(\@chunks), Dumper($out))) {
    diag("Above failure from expr: ".Dumper($expr));
  }
}

done_testing;
