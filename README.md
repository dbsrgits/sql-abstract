# SQL::Abstract

Generate SQL from Perl data structures.

SQL::Abstract turns Perl hashes and arrays into an SQL statement plus a
list of bind values, ready for DBI. Values always end up as bind values,
never in the SQL text.

```perl
use SQL::Abstract;

my $sql = SQL::Abstract->new;

my ($stmt, @bind) = $sql->select(
  'people',
  [qw(name email)],
  { status => 'active', age => { '>' => 18 } },
  'name',
);
# $stmt: SELECT name, email FROM people WHERE ( age > ? AND status = ? ) ORDER BY name
# @bind: (18, 'active')

my $sth = $dbh->prepare($stmt);
$sth->execute(@bind);
```

The same works for `insert`, `update`, `delete` and plain `where`.
See the [full documentation on MetaCPAN](https://metacpan.org/pod/SQL::Abstract).

The distribution also contains:

- [SQL::Abstract::Tree](https://metacpan.org/pod/SQL::Abstract::Tree) -
  parses and pretty-prints SQL (for debug output)
- [SQL::Abstract::Test](https://metacpan.org/pod/SQL::Abstract::Test) -
  compares SQL and bind values in tests, ignoring formatting

## Installation

```sh
cpanm SQL::Abstract
```

From a git checkout:

```sh
perl Makefile.PL
make
make test
make install
```

## DBIx::Class and DBIO

[DBIx::Class](https://metacpan.org/pod/DBIx::Class) no longer uses this
module: since 0.082842 it uses
[SQL::Abstract::Classic](https://metacpan.org/pod/SQL::Abstract::Classic),
a frozen copy of the 1.x line.

[DBIO](https://metacpan.org/pod/DBIO), a fork of DBIx::Class, builds its
SQL with SQL::Abstract 2.x and uses SQL::Abstract::Tree for its query
trace.

## Support

- Bugs: [rt.cpan.org](https://rt.cpan.org/Public/Dist/Display.html?Name=SQL-Abstract)
- IRC: `#dbio` on `irc.perl.org`
- Maintainer: Torsten Raudssus <torsten@raudssus.de>

Security issues: please do **not** report them publicly, see
[SECURITY.md](SECURITY.md).

## License

Copyright (c) 2001-2026 Nathan Wiger and the SQL::Abstract contributors.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself. See
[LICENSE](LICENSE).
