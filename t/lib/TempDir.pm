package TempDir;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(mk_temp_dir mk_temp_ll_dir mk_temp_file);

use local::lib ();
use Cwd;
use File::Spec;
use File::Temp ();

my $temp_root = File::Spec->tmpdir;

if ($ENV{LOCAL_LIB_TEST_DEBUG}) {
  $File::Temp::KEEP_ALL = 1;
  mkdir 't/temp';
  $temp_root = Cwd::abs_path('t/temp')
}

# On Win32 the path where the distribution is built usually contains
# spaces. This is a problem for some parts of the CPAN toolchain, so
# local::lib uses the GetShortPathName trick do get an alternate
# representation of the path that doesn't constain spaces.
$temp_root = Win32::GetShortPathName($temp_root)
  if $^O eq 'MSWin32';

sub _template {
  my $i = 0;
  my $file = shift;
  if (!$file) {
    while (my ($p, $f) = caller($i++)) {
      next
        if $p eq __PACKAGE__;
      $file = $f;
      $file =~ s{^t[/\\]}{};
      $file =~ s{\.t$}{};
      $file =~ s{[^a-z0-9_-]+}{-}gi;
    }
  }
  'local-lib-'.($file||'test').'-XXXXXX';
}

sub mk_temp_dir {
  my $opts = (@_ && ref $_[-1]) ? pop : {};
  my $name_template = _template(shift);

  File::Temp::tempdir(
    $name_template,
    DIR => $temp_root,
    CLEANUP => 1,
    %$opts
  );
}

sub mk_temp_ll_dir {
  my $path = mk_temp_dir(@_);
  local::lib->ensure_dir_structure_for($path, { quiet => 1 });
  local::lib->normalize_path($path);
}

sub mk_temp_file {
  my $opts = (@_ && ref $_[-1]) ? pop : {};
  my $name_template = _template(shift);

  File::Temp::tempfile(
    $name_template,
    DIR => $temp_root,
    UNLINK => 1,
    %$opts,
  );
}

1;
