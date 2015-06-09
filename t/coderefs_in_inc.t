use strict;
use warnings;
use Test::More tests => 2;
use lib 't/lib';
use TempDir;
use Cwd;

# Test that refs in @INC don't get mangled.

my $dir = mk_temp_dir('test_local_lib-XXXXX');

use local::lib ();
my $code = sub {};
push(@INC, $code);
local::lib->import($dir);
ok grep({ $_ eq $code } @INC), 'Can find code ref in @INC';
ok grep({ ref $_ } @INC), 'It really is a ref, not stringified';

