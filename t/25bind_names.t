use strict;
use warnings;
use Test::More;

use SQL::Abstract;

my $sql = SQL::Abstract->new;

my $A = bless(["a"], 'A');
my $B = bless(["b"], 'B');
my $X1 = bless(["x1"], 'X');
my $X2 = bless(["x2"], 'X');

my $where = [{a => $A, b => $B}, {x => { '-in' => [$X1, $X2]}}];

subtest select => sub {
    my @bind_names;
    my ($stmt, @bind) = $sql->select(
        'foo',
        ['a', 'b'],
        $where,
        undef, # order_by
        \@bind_names,
    );

    is($stmt, 'SELECT a, b FROM foo WHERE ( ( a = ? AND b = ? ) OR x IN ( ?, ? ) )', "Got correct statement");
    is_deeply(
        \@bind,
        [$A, $B, $X1, $X2],
        "Got expected binds in correct order"
    );
    is_deeply(
        \@bind_names,
        [qw/a b x x/],
        "Got the column names of all the binds in order"
    );
};

subtest where => sub {
    my @bind_names;
    my ($stmt, @bind) = $sql->where(
        $where,
        undef, # order by
        \@bind_names,
    );

    # Not sure why, but these WHERE has one extra set of parens compared to the select() version
    is($stmt, ' WHERE ( ( ( a = ? AND b = ? ) OR x IN ( ?, ? ) ) )', "Got correct statement");
    is_deeply(
        \@bind,
        [$A, $B, $X1, $X2],
        "Got expected binds in correct order"
    );
    is_deeply(
        \@bind_names,
        [qw/a b x x/],
        "Got the column names of all the binds in order"
    );
};

done_testing;
