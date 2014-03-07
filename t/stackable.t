use strict;
use warnings;
use Test::More;
use File::Spec;
use Config;

plan tests => 24;

use local::lib ();

use lib 't/lib'; use TempDir;

delete $ENV{PERL_LOCAL_LIB_ROOT};

my $dir1 = mk_temp_dir('test_local_lib-XXXXX');
my $dir2 = mk_temp_dir('test_local_lib-XXXXX');

my ($dir1_arch, $dir2_arch) = map { File::Spec->catfile($_, qw'lib perl5', $Config{archname}) } $dir1, $dir2;

my $prev_active = () = local::lib->active_paths;

local::lib->import($dir1);
is +() = local::lib->active_paths, $prev_active + 1, 'one active path';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'added one dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'added one dir in lib';
unlike $ENV{PERL5LIB}, qr/\Q$dir1_arch/, 'no arch in PERL5LIB';
my $dir1_escape = local::lib::_mm_escape_path($dir1);
like $ENV{PERL_MM_OPT}, qr/\Q$dir1_escape/, 'first path is installation target';

local::lib->import($dir1);
is +() = local::lib->active_paths, $prev_active + 1, 'still one active path after adding it twice';

local::lib->import($dir2);
is +() = local::lib->active_paths, $prev_active + 2, 'two active paths';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, 'added another dir in root';
like $ENV{PERL5LIB}, qr/\Q$dir2/, 'added another dir in lib';
unlike $ENV{PERL5LIB}, qr/\Q$dir2_arch/, 'no arch in PERL5LIB';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, 'first dir is still in root';
like $ENV{PERL5LIB}, qr/\Q$dir1/, 'first dir is still in lib';
unlike $ENV{PERL5LIB}, qr/\Q$dir1_arch/, 'no arch in PERL5LIB';
my $dir2_escape = local::lib::_mm_escape_path($dir2);
like $ENV{PERL_MM_OPT}, qr/\Q$dir2_escape/, 'second path is installation target';

local::lib->import($dir1);
my @active = local::lib->active_paths;
is @active, $prev_active + 2, 'still two active dirs after re-adding first';
is $active[0], $dir1, 'first dir was re-added on top';
like $ENV{PERL_MM_OPT}, qr/\Q$dir1_escape/, 'first path is installation target again';

local::lib->import('--deactivate', $dir2);
unlike $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir2/, 'second dir was removed from root';
unlike $ENV{PERL5LIB}, qr/\Q$dir2/, 'second dir was removed from lib';
unlike $ENV{PERL5LIB}, qr/\Q$dir2_arch/, 'no arch in PERL5LIB';
like $ENV{PERL_LOCAL_LIB_ROOT}, qr/\Q$dir1/, q{first dir didn't go away from root};
like $ENV{PERL5LIB}, qr/\Q$dir1/, q{first dir didn't go away from lib};
unlike $ENV{PERL5LIB}, qr/\Q$dir1_arch/, 'no arch in PERL5LIB';
like $ENV{PERL_MM_OPT}, qr/\Q$dir1_escape/, 'first dir stays installation target';
