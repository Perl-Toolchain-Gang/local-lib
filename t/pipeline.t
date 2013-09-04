
use strict;
use warnings;
use Test::More 'no_plan';
use local::lib ();

{

package local::lib;

{ package Foo; sub foo { -$_[1] } sub bar { $_[1]+2 } sub baz { $_[1]+3 } }
my $foo = bless({}, 'Foo');
Test::More::ok($foo->${pipeline qw(foo bar baz)}(10) == -15);

}
