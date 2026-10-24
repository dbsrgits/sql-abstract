# Security Policy for SQL::Abstract

This is the security policy for the Perl distribution SQL-Abstract
(SQL::Abstract, SQL::Abstract::Tree, SQL::Abstract::Test and the
plugins shipped with it).

## Reporting a security issue

**Please do not report security issues in public places** - not on
rt.cpan.org, not in a GitHub pull request or issue, and not on IRC.

Send a private email to the maintainer instead:

    Torsten Raudssus <torsten@raudssus.de>

If you get no answer within 7 days, or the issue is urgent, contact the
CPAN Security Group:

    cpan-security@security.metacpan.org

A useful report contains:

- the SQL::Abstract version (and perl version)
- a minimal piece of Perl code that shows the problem
- the generated SQL and bind values, and what you expected instead
- what an attacker can do with it

## What happens next

- You get an answer within 7 days. This is a volunteer project, so
  please be patient.
- The issue is checked and, if confirmed, fixed in a new release.
  Fixes are coordinated with the CPAN Security Group, which can also
  assign a CVE.
- You are credited in the Changes file unless you ask not to be.

## Supported versions

Only the latest release of SQL::Abstract 2.x gets security fixes.
Please check that the issue still exists there before reporting.

The 1.x line is no longer maintained. DBIx::Class does not use
SQL::Abstract any more (it uses SQL::Abstract::Classic since
DBIx::Class 0.082842); please report DBIx::Class issues to that project.

## What counts as a security issue

SQL::Abstract turns Perl data structures into SQL plus bind values.
Its job is to make sure that **values** end up as bind values, never
in the SQL text. It is a security issue if:

- a value (a where value, insert or update data, a -in / -between
  list, a bind value) ends up in the SQL text instead of in @bind
- an identifier quoted with `quote_char` can break out of its quotes
- `injection_guard` lets through something its documentation says it
  rejects

These are **not** security issues, because they are documented
behaviour and the calling code is responsible for them:

- **Identifiers are SQL, not values.** Table names, column names, the
  keys of a where hash, select field lists and ORDER BY / GROUP BY
  entries are put into the SQL text. Never pass untrusted input as an
  identifier; map it onto an allow-list instead. See "CAVEAT: untrusted
  input in ORDER BY" in the SQL::Abstract documentation, and set
  `quote_char`.
- **Literal SQL is passed through as-is.** `\"..."` and `\["...", @bind]`
  are inserted verbatim by design.
- **Operator names** (`-op` keys, `special_ops`, `unary_ops`) are code,
  not data. Do not build them from untrusted input.
- `injection_guard` is a last-resort check for a few obvious patterns,
  not a full SQL injection filter.
- SQL::Abstract::Tree only formats SQL for humans (debug output, test
  comparisons). Its output is not meant to be executed, so a wrong
  parse or format is a normal bug - please report it on rt.cpan.org.
