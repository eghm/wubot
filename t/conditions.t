#!/perl
use strict;

use Test::More;
use Test::Routine;
use Test::Routine::Util;

use App::Wubot::Logger;
use App::Wubot::Conditions;

has reactor => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_reactor',
    default => sub {
        App::Wubot::Conditions->new();
    },
);

test "test conditions object" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( ! $self->reactor->istrue(),
        "Checking that conditions object is useable"
    );

};

test "matches" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo matches test", { foo => 'test' } ),
        "Checking 'foo matches test' when foo = test"
    );

    ok( $self->reactor->istrue( "foo matches test", { foo => 'test1' } ),
        "Checking 'foo matches test' when foo = test1"
    );

    ok( ! $self->reactor->istrue( "foo matches test", { foo => 'asdf' } ),
        "Checking 'foo matches test' when foo = asdf"
    );

    ok( ! $self->reactor->istrue( "foo matches test", { foo => 'TEST' } ),
        "Checking 'foo does not match test' when foo = TEST"
    );

    ok( $self->reactor->istrue( "foo matches ^Abc", { foo => "Abc-def" } ),
        "Checking 'foo matches ^Abc' when foo = Abc-def"
    );

    ok( $self->reactor->istrue( "foo matches now is the time", { foo => "now is the time for all" } ),
        "Checking 'foo matches now is the time' when foo = now is the time for all"
    );
};

test "imatches" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo imatches test", { foo => 'test' } ),
        "Checking 'foo imatches test' when foo = test"
    );

    ok( $self->reactor->istrue( "foo imatches test", { foo => 'TEST' } ),
        "Checking 'foo imatches test' when foo = TEST"
    );
};

test "equals" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo equals test", { foo => 'test' } ),
        "Checking 'foo equals test' when foo = test"
    );

    ok( ! $self->reactor->istrue( "foo equals test", { foo => 'test1' } ),
        "Checking 'foo equals test' when foo = test1"
    );
};

test "contains" => sub {
    my ($self) = @_;

    $self->reset_reactor;


    ok( $self->reactor->istrue( "contains foo", { foo => 'test1' } ),
        "Checking 'contains foo' when foo = test1"
    );

    ok( $self->reactor->istrue( "contains foo", { foo => undef } ),
        "Checking 'contains foo' when foo = undef"
    );

    ok( ! $self->reactor->istrue( "contains bar", { foo => 'test1' } ),
        "Checking 'contains bar' when it does not"
    );
};

test "is true" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo is true", { foo => 'test1' } ),
        "Checking 'foo is true' when foo = test1"
    );

    ok( ! $self->reactor->istrue( "foo is true", { foo => undef } ),
        "Checking 'foo is true' when foo = undef"
    );

    ok( ! $self->reactor->istrue( "foo is true", { foo => 0 } ),
        "Checking 'foo is true' when foo = 0"
    );

    ok( ! $self->reactor->istrue( "foo is true", { foo => "" } ),
        "Checking 'foo is true' when foo = blank"
    );

    ok( $self->reactor->istrue( "foo is true", { foo => "true" } ),
        "Checking 'foo is true' when foo = true"
    );

    ok( ! $self->reactor->istrue( "foo is true", { foo => "false" } ),
        "Checking 'foo is true' when foo = false"
    );
};

test "is false" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( ! $self->reactor->istrue( "foo is false", { foo => 'test1' } ),
        "Checking 'foo is false' when foo = test1"
    );

    ok( $self->reactor->istrue( "foo is false", { foo => undef } ),
        "Checking 'foo is false' when foo = undef"
    );

    ok( $self->reactor->istrue( "foo is false", { foo => 0 } ),
        "Checking 'foo is false' when foo = 0"
    );

    ok( $self->reactor->istrue( "foo is false", { foo => "" } ),
        "Checking 'foo is false' when foo = blank"
    );

    ok( $self->reactor->istrue( "foo is false", { foo => "false" } ),
        "Checking 'foo is false' when foo = false"
    );

    ok( ! $self->reactor->istrue( "foo is false", { foo => "true" } ),
        "Checking 'foo is false' when foo = true"
    );
};

test "AND" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo is true AND bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'foo is true AND bar is true' when foo and bar are true"
    );

    ok( ! $self->reactor->istrue( "foo is true AND bar is true", { foo => "abc" } ),
        "Checking compound rule 'foo is true AND bar is true' when bar is not set"
    );

    ok( $self->reactor->istrue( "foo matches x AND foo matches a b c", { foo => 'x a b c y' } ),
        "Checking 'foo matches x AND foo matches a b c' when foo = x a b c y"
    );
};

test 'OR' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo is true OR bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'foo is true OR bar is true' when foo and bar are true"
    );

    ok( $self->reactor->istrue( "foo is true OR bar is true", { foo => "abc" } ),
        "Checking compound rule 'foo is true OR bar is true' when bar is not set"
    );

    ok( ! $self->reactor->istrue( "foo is true OR bar is true", { 'abc' => 'xyz' } ),
        "Checking compound rule 'foo is true OR bar is true' when both are not set"
    );
};

test 'combinations of AND and OR with NOT' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( ! $self->reactor->istrue( "NOT foo is true AND NOT bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'NOT foo is true AND NOT bar is true' when foo and bar are true"
    );

    ok( $self->reactor->istrue( "NOT foo is true AND NOT bar is true", { 'abc' => 'def' } ),
        "Checking compound rule 'NOT foo is true AND NOT bar is true' when foo and bar are false"
    );

    ok( ! $self->reactor->istrue( "hostname equals navi AND NOT no_post is true", { hostname => 'xyz' } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when hostname is xyz"
    );

    ok( ! $self->reactor->istrue( "hostname equals navi AND NOT no_post is true", { no_post => 1 } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when no_post set"
    );

    ok( ! $self->reactor->istrue( "hostname equals navi AND NOT no_post is true", { hostname => 'xyz', no_post => 1 } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post'"
    );

    ok( $self->reactor->istrue( "hostname equals navi AND NOT no_post is true", { hostname => 'navi' } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post'"
    );

};

test 'permutations of three statements with AND and OR' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "hostname equals navi AND hostname equals navi OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'true AND true OR true' is true"
    );
    ok( $self->reactor->istrue( "hostname equals navi AND hostname equals navi OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'true AND true OR false' is true"
    );
    ok( $self->reactor->istrue( "hostname equals navi AND abc equals xyz OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'true AND false OR true' is true"
    );
    ok( ! $self->reactor->istrue( "abc equals xyz AND hostname equals navi OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'false AND true OR true' is false"
    );
    ok( ! $self->reactor->istrue( "abc equals xyz AND abc equals xyz OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'false AND false OR true' is false"
    );
    ok( ! $self->reactor->istrue( "abc equals xyz AND hostname equals navi OR  abc equals xyz", { hostname => 'navi' } ),
        "Checking 'false AND true OR false' is false"
    );
    ok( ! $self->reactor->istrue( "hostname equals navi AND abc equals xyz OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'true AND false OR false' is false"
    );
    ok( ! $self->reactor->istrue( "abc equals xyz AND abc equals xyz OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'false AND false OR false' is false"
    );
};


test 'less than and greater than' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo < 5", { foo => '1' } ),
        "Checking 'foo < 5' when foo = 1"
    );

    ok( ! $self->reactor->istrue( "foo < 5", { foo => '6' } ),
        "Checking 'foo < 5' when foo = 6"
    );

    ok( ! $self->reactor->istrue( "foo > 5", { foo => '1' } ),
        "Checking 'foo > 5' when foo = 1"
    );

    ok( $self->reactor->istrue( "foo > 5", { foo => '6' } ),
        "Checking 'foo > 5' when foo = 6"
    );

    ok( ! $self->reactor->istrue( "foo > bar", { foo => '6', bar => '7' } ),
        "Checking 'foo > bar' when foo = 6, bar = 7"
    );

    ok( $self->reactor->istrue( "foo > bar", { foo => '7', bar => '6' } ),
        "Checking 'foo > bar' when foo = 7, bar = 6"
    );

    ok( $self->reactor->istrue( "foo < bar", { foo => '6', bar => '7' } ),
        "Checking 'foo < bar' when foo = 6, bar = 7"
    );

    ok( ! $self->reactor->istrue( "foo < bar", { bar => '6' } ),
        "Checking 'foo < bar' when foo is undefined"
    );

    ok( ! $self->reactor->istrue( "foo < bar", { foo => '6' } ),
        "Checking 'foo < bar' when bar is undefined"
    );
};

test 'less than or equal to, and greater than or equal to' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "foo >= 5", { foo => '6' } ),
        "Checking 'foo >= 5' when foo = 6"
    );

    ok( $self->reactor->istrue( "foo >= 5", { foo => '5' } ),
        "Checking 'foo >= 5' when foo = 5"
    );

    ok( ! $self->reactor->istrue( "foo >= 5", { foo => '4' } ),
        "Checking 'foo >= 5' when foo = 4"
    );

    ok( $self->reactor->istrue( "foo <= 5", { foo => '4' } ),
        "Checking 'foo <= 5' when foo = 4"
    );

    ok( $self->reactor->istrue( "foo <= 5", { foo => '5' } ),
        "Checking 'foo <= 5' when foo = 5"
    );

    ok( ! $self->reactor->istrue( "foo <= 5", { foo => '6' } ),
        "Checking 'foo <= 4' when foo = 6"
    );

};

test 'conditions with parens' => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->istrue( "( hostname equals navi OR hostname equals foo ) AND hostname equals navi", { hostname => 'navi' } ),
        "Checking ( true OR false ) AND true"
    );

    ok( $self->reactor->istrue( "hostname equals navi OR ( hostname equals foo AND hostname equals navi )", { hostname => 'navi' } ),
        "Checking true OR ( false AND true )"
    );

    ok( $self->reactor->istrue( "hostname equals navi OR ( hostname equals foo AND hostname equals navi )", { hostname => 'navi' } ),
        "Checking true OR ( false AND true )"
    );

    ok( $self->reactor->istrue( "hostname equals foo OR ( hostname equals navi AND hostname equals navi )", { hostname => 'navi' } ),
        "Checking false OR ( true AND true )"
    );

    ok( ! $self->reactor->istrue( "hostname equals foo OR ( hostname equals navi AND hostname equals foo )", { hostname => 'navi' } ),
        "Checking false OR ( true AND false )"
    );

    ok( $self->reactor->istrue( "( hostname equals navi OR hostname equals foo ) AND ( hostname equals foo OR hostname equals navi )", { hostname => 'navi' } ),
        "Checking ( true OR false ) AND ( false OR true )"
    );

    ok( $self->reactor->istrue( "( ( hostname equals foo OR hostname equals bar ) OR hostname equals navi ) AND hostname equals navi", { hostname => 'navi' } ),
        "Checking ( ( FALSE OR FALSE ) OR TRUE ) AND TRUE"
    );

    ok( $self->reactor->istrue( "( hostname equals foo OR ( hostname equals bar OR hostname equals navi ) ) AND hostname equals navi", { hostname => 'navi' } ),
        "Checking ( FALSE OR ( FALSE OR TRUE ) ) AND TRUE"
    );

    ok( $self->reactor->istrue( "( abc equals xyz AND hostname equals navi ) OR hostname equals navi", { hostname => 'navi' } ),
        "Checking '( false AND true ) OR true' is true"
    );
};

run_me;
done_testing;
