use strict;
use warnings;
use Test::More;
BEGIN { plan skip_all => "Install Capture::Tiny to test installation"
  unless eval { require Capture::Tiny; 1 } }
use Capture::Tiny qw(capture);
use File::Temp qw(tempdir);
use File::Spec;
use Cwd;
use Config;

plan tests => 2;

my $dir = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

use local::lib ();
local::lib->import($dir);

my $orig_dir = cwd;
SKIP: for my $dist_type (qw(EUMM MB)) {
  chdir File::Spec->catdir($orig_dir, qw(t dist), $dist_type);
  if ($dist_type eq 'EUMM') {
    my ($stdout, $stderr) = capture { eval { 
      system($^X, 'Makefile.PL') && die "Makefile.PL failed";
      system($Config{make}, 'install') && die "$Config{make} install failed";
    } };
    diag $stdout, $stderr if $@;
  } else {
    my ($stdout, $stderr) = capture { eval {
      system($^X, 'Build.PL') && die "Build.PL failed";
      system($^X, 'Build', 'install') && die "Build install failed";
    } };
    diag $stdout, $stderr if $@;
  }
  ok(
    -e File::Spec->catfile(
      $dir, qw(lib perl5), "$dist_type.pm",
    ),
    "$dist_type.pm installed into the correct location",
  );
}
