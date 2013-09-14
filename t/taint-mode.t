#
# t/taint-mode.t: checks that local::lib sets up @INC correctly when
# included in a script that has taint mode on, and is executing in an
# environment in which local::lib has already been loaded.
#

use strict;
use warnings;
use Test::More tests => 1;
use File::Temp 'tempfile';
use Cwd;

use lib 't/lib'; use TempDir;

my $dir1 = mk_temp_dir('test_local_lib-XXXXX');

# Set up local::lib environment using our temp dir
require local::lib;
local::lib->import($dir1);

# Create a script that has taint mode turned on, and tries to use a
# local lib to the same temp dir.
my ($fh, $filename) = tempfile('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), UNLINK => 1);

print $fh <<EOM;
#!/usr/bin/perl -T
use strict; use warnings;
use local::lib '$dir1';
my \$dir1 = '$dir1';
if (grep { m{^\\Q\$dir1\\E/} } \@INC) {
  exit 0;
}
exit 1
EOM
close $fh;

my $exit_val = system($^X, '-Ilib', '-T', $filename);

is($exit_val >> 8, 0, 'test script exited with 0, local::lib dir found in @INC');
