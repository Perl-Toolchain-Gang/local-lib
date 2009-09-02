use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd;

# Test that refs in @INC don't get mangled.

plan tests => 2;

my $dir = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

use local::lib ();
my $code = sub {};
push(@INC, $code);
local::lib->import($dir);
ok grep({ $_ eq $code } @INC), 'Can find code ref in @INC';
ok grep({ ref $_ } @INC), 'It really is a ref, not stringified';

