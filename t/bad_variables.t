use strict;
use warnings;
use Test::More tests => 5;
use File::Temp 'tempdir';
use local::lib ();

# remember the original value of this, in case we are already running inside a
# local::lib
my $orig_llr = $ENV{PERL_LOCAL_LIB_ROOT} || '';

my $dir1 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);
my $dir2 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);
my $dir3 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

ok(!(grep { $dir1 eq $_ } @INC), 'new dir is not already in @INC');
ok(!(grep { $dir1 eq $_ } split /:/, ($ENV{PERL5LIB}||'')), 'new dir is not already in PERL5LIB');

local::lib->import($dir1);
local::lib->import($dir2);

# we have junk in here now
$ENV{PERL_LOCAL_LIB_ROOT} .= ':' . $dir3;

local::lib->import($dir1);

is(
    $ENV{PERL_LOCAL_LIB_ROOT},
    join(':', (grep { $_ } $orig_llr, $dir2, $dir1)),
    'dir1 should have been removed and added back in at the top',
);

ok((grep { /\Q$dir1\E/ } @INC), 'new dir has been added to @INC');
ok((grep { /\Q$dir1\E/ } split /:/, $ENV{PERL5LIB}), 'new dir has been added to PERL5LIB');

