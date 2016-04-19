use strict;
use warnings;
use Test::More tests => 1;

use local::lib ();

{
  package Foo;
  sub new { bless {}, $_[0] }
  sub foo { -$_[1] }
  sub bar { $_[1]+2 }
  sub baz { $_[1]+3 }
}

is +Foo->new->${local::lib::pipeline qw(foo bar baz)}(10), -15;
