package SQL::Abstract::ExtraClauses;

use strict;
use warnings;
use if $] < '5.010', 'MRO::Compat';
use mro 'c3';
use base qw(SQL::Abstract::Clauses);

BEGIN { *puke = \&SQL::Abstract::puke }

sub new {
  my ($proto, @args) = @_;
  my $new = $proto->next::method(@args);
  $new->{clauses_of}{select} = [
    @{$new->{clauses_of}{select}}, qw(group_by having)
  ];
  $new->{expand_clause}{'select.group_by'} = sub {
    $_[0]->_expand_maybe_list_expr($_[1], -ident)
  };
  $new->{expand_clause}{'select.having'} = sub {
    $_[0]->expand_expr($_[1], -ident)
  };
  return $new;
}

1;
