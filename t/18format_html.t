use strict;
use warnings;
use Test::More;
use SQL::Abstract::Tree;

# The html profile emits markup (<span>, <br />), so the SQL text and the
# filled in bind values around that markup must be HTML-escaped.

my $sql = q{SELECT "<b>" FROM t WHERE a < ? AND b <> '<i>'};

{
  my $sqlat = SQL::Abstract::Tree->new({ profile => 'html' });

  is(
    $sqlat->format($sql, [ '<script>alert(1)</script>' ]),
    join("<br />\n",
      '<span class="select">SELECT</span> &quot;&lt;b&gt;&quot; ',
      '&nbsp;&nbsp;<span class="from">FROM</span> t ',
      '<span class="where">WHERE</span> a &lt; '
        . '<span class="placeholder">&lt;script&gt;alert(1)&lt;/script&gt;</span>'
        . ' AND b &lt;&gt; &#39;&lt;i&gt;&#39;',
    ),
    'html profile escapes SQL text and bind values, keeps its own markup',
  );

  like(
    $sqlat->format('SELECT x FROM t WHERE y = ?', [ q{"a" & 'b'} ]),
    qr{<span class="placeholder">&quot;a&quot; &amp; \\&#39;b\\&#39;</span>},
    'quotes and ampersands in bind values are escaped',
  );

  like(
    $sqlat->format('SELECT "f<"( y ) FROM t'),
    qr{</span> &quot;f&lt;&quot;\( y \)},
    'function names are escaped',
  );
}

{
  my $sqlat = SQL::Abstract::Tree->new({
    profile => 'html', html_escape => 0,
  });
  like(
    $sqlat->format('SELECT x FROM t WHERE y < ?', [ '<b>' ]),
    qr{y < <span class="placeholder"><b></span>},
    'html_escape => 0 turns escaping off',
  );
}

{
  my $sqlat = SQL::Abstract::Tree->new({ profile => 'console_monochrome' });
  is(
    $sqlat->format('SELECT x FROM t WHERE y < ?', [ '<b>' ]),
    "SELECT x \n  FROM t \nWHERE y < ?/<b>",
    'console profiles are not escaped',
  );
}

done_testing;
