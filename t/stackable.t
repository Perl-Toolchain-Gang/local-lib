use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd;

plan tests => 19;

my $dir1 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);
my $dir2 = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

use local::lib ();

local::lib->import($dir1);
is +() = local::lib->active_paths, 1, 'one active path';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'added one dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'added one dir in lib';
like $ENV{PERL_MM_OPT}, qr/\Q$dir1/, 'first path is installation target';

local::lib->import($dir1);
is +() = local::lib->active_paths, 1, 'still one active path after adding it twice';

local::lib->import($dir2);
is +() = local::lib->active_paths, 2, 'two active paths';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, 'added another dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir2/, 'added another dir in lib';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'first dir is still in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'first dir is still in lib';
like $ENV{PERL_MM_OPT}, qr/\Q$dir2/, 'second path is installation target';

local::lib->import($dir1);
my @active = local::lib->active_paths;
is @active, 2, 'still two active dirs after re-adding first';
is $active[-1], $dir1, 'first dir was re-added on top';
like $ENV{PERL_MM_OPT}, qr/\Q$dir1/, 'first path is installation target again';

local::lib->import('--deactivate', $dir2);
unlike $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, 'second dir was removed from root';
unlike $ENV{PERL5LIB}, qr/\Q$dir2/, 'second dir was removed from lib';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, q{first dir didn't go away from root};
like $ENV{PERL5LIB}, qr/\Q$dir1/, q{first dir didn't go away from lib};
like $ENV{PERL_MM_OPT}, qr/\Q$dir1/, 'first dir stays installation target';
