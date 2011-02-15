use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd;

plan tests => 11;

my $dir1 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);
my $dir2 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

use local::lib ();

local::lib->import($dir1);
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'added one dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'added one dir in lib';

local::lib->import($dir2);
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, 'added another dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir2/, 'added another dir in lib';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'first dir is still in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'first dir is still in lib';

local::lib->import('--deactivate', $dir1);
unlike $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'first dir was removed from root';
unlike $ENV{PERL5LIB}, qr/\Q$dir1/, 'first dir was removed from lib';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, q{second dir didn't go away from root};
like $ENV{PERL5LIB}, qr/\Q$dir2/, q{second dir didn't go away from lib};
like $ENV{PERL_MM_OPT}, qr/\Q$dir2/, q{second dir stays installation target};
