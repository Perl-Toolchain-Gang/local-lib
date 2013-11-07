use strict;
use warnings;
use Test::More tests => 6;
use File::Temp 'tempdir';
use Config;
use local::lib ();

use lib 't/lib'; use TempDir;

delete $ENV{PERL_LOCAL_LIB_ROOT};

my $dir1 = mk_temp_dir('test_local_lib-XXXXX');
my $dir2 = mk_temp_dir('test_local_lib-XXXXX');
my $dir3 = mk_temp_dir('test_local_lib-XXXXX');

ok(!(grep { $dir1 eq $_ } @INC), 'new dir is not already in @INC');
ok(!(grep { $dir1 eq $_ } split /\Q$Config{path_sep}\E/, ($ENV{PERL5LIB}||'')), 'new dir is not already in PERL5LIB');

local::lib->import($dir1);
local::lib->import($dir2);

# we have junk in here now
$ENV{PERL_LOCAL_LIB_ROOT} = $dir3 . $Config{path_sep} . $ENV{PERL_LOCAL_LIB_ROOT};

local::lib->import($dir1);

is(
    $ENV{PERL_LOCAL_LIB_ROOT},
    join($Config{path_sep}, (grep { defined $_ and $_ ne '' } $dir1, $dir3, $dir2)),
    'dir1 should have been removed and added back in at the top'
);

ok((!grep { $_ eq $dir3 } local::lib->active_paths), 'junk dir added not included in active_paths');

ok((grep { /\Q$dir1\E/ } @INC), 'new dir has been added to @INC');
ok((grep { /\Q$dir1\E/ } split /\Q$Config{path_sep}\E/, $ENV{PERL5LIB}), 'new dir has been added to PERL5LIB');

