use strict;
use warnings;

use SQL::Abstract::Tree;

my $sqlat = SQL::Abstract::Tree->new({});

{
   my $sql = "SELECT a, b, c FROM foo WHERE foo.a =1 and foo.b LIKE 'station'";

   print "$sql\n";
   print $sqlat->format($sql) . "\n";
}

{
   my $sql = "SELECT * FROM (SELECT * FROM foobar) WHERE foo.a =1 and foo.b LIKE 'station'";

   print "$sql\n";
   print $sqlat->format($sql) . "\n";
}

{
   my $sql = "SELECT * FROM lolz WHERE ( foo.a =1 ) and foo.b LIKE 'station'";

   print "$sql\n";
   print $sqlat->format($sql) . "\n";
}

# stuff we want:
#    Nested indentation
#    Max Width
#    Color coding (console)
#    Color coding (html)
