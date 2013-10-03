use strict;
use warnings;
use Test::More;
BEGIN { plan skip_all => "Install Capture::Tiny to test installation"
  unless eval { require Capture::Tiny; 1 } }
use Capture::Tiny qw(capture);
use File::Spec;
use Cwd;
use Config;

use lib 't/lib'; use TempDir;

plan tests => 2;

my $dir = mk_temp_dir('test_local_lib-XXXXX');

use local::lib ();
local::lib->import($dir);

my $orig_dir = cwd;
SKIP: for my $dist_type (qw(MB EUMM)) {
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
  my $file = File::Spec->catfile($dir, qw(lib perl5), "$dist_type.pm");
  ok(
    -e $file,
    "$dist_type - $dist_type.pm installed as $file",
  )
  or do {
        my $dest_dir = File::Spec->catdir($dir, qw(lib perl5));
        diag 'Files in ' . $dest_dir . ":\n", join("\n", glob(File::Spec->catfile($dest_dir, '*')));
  };
}
