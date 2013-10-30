package TempDir;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(mk_temp_dir);

use local::lib ();
use Cwd;
use File::Temp qw(tempdir);

$File::Temp::KEEP_ALL = 1
  if $ENV{LOCAL_LIB_TEST_DEBUG};

sub mk_temp_dir
{
    my $name_template = shift;

    mkdir 't/temp';
    my $path = tempdir($name_template, DIR => Cwd::abs_path('t/temp'), CLEANUP => 1);
    local::lib->ensure_dir_structure_for($path);
    # On Win32 the path where the distribution is built usually contains
    # spaces. This is a problem for some parts of the CPAN toolchain, so
    # local::lib uses the GetShortPathName trick do get an alternate
    # representation of the path that doesn't constain spaces.
    return ($^O eq 'MSWin32')
         ? Win32::GetShortPathName($path)
	 : $path
}

1;
