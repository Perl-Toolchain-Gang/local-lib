
use strict;
use warnings;
use Test::More 'no_plan';
use local::lib ();


my $c = 'local::lib';


{

is($c->resolve_empty_path, '~/perl5');
is($c->resolve_empty_path('foo'), 'foo');

}

{

local *File::Spec::rel2abs = sub { shift; 'FOO'.shift; };
is($c->resolve_relative_path('bar'),'FOObar');

}

{

File::Path::rmtree('t/var/splat');

$c->ensure_dir_structure_for('t/var/splat');

ok(-d 't/var/splat');

}
