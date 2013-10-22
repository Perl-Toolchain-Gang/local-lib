use strict;
use warnings;
use Test::More;
BEGIN { plan skip_all => "Install Capture::Tiny to test installation"
  unless eval { require Capture::Tiny; 1 } }
use Capture::Tiny qw(capture_merged);
use File::Spec;
use File::Path qw(mkpath);
use Cwd;
use Config;

use lib 't/lib'; use TempDir;

use local::lib ();

my @dirs = (
  'plain',
  'with space',
  'with\backslash',
  'with space\and-bs',
);

my %dist_types = (
  EUMM => sub {
    system($^X, 'Makefile.PL') && die "Makefile.PL failed";
    system($Config{make}, 'install') && die "$Config{make} install failed";
  },
  MB => sub {
    system($^X, 'Build.PL') && die "Build.PL failed";
    system($^X, 'Build', 'install') && die "Build install failed";
  },
);

plan tests => @dirs * keys(%dist_types) * 2;

my $orig_dir = cwd;
for my $dir_base (@dirs) {
  for my $dist_type (sort keys %dist_types) {
    chdir $orig_dir;
    my $temp = mk_temp_dir('test_local_lib-XXXXX');
    my $ll_dir = "$dist_type-$dir_base";
    mkpath(my $ll = "$temp/$ll_dir");
    local::lib->import($ll);

    chdir File::Spec->catdir($orig_dir, qw(t dist), $dist_type);
    my $output = capture_merged { eval {
      $dist_types{$dist_type}->();
    } };
    is $@, '', "installed $dist_type into '$ll_dir'"
      or diag $output;

    my $dest_dir = local::lib->install_base_perl_path($ll);
    my $file = File::Spec->catfile($dest_dir, "$dist_type.pm");
    (my $short_file = $file) =~ s/^\Q$ll/$ll_dir/;
    ok(
      -e $file,
      "$dist_type - $dir_base - $dist_type.pm installed as '$short_file'",
    ) or diag 'Files in ' . $dest_dir . ":\n", join("\n", do {
      my $dh;
      (opendir $dh, $dest_dir) ? readdir $dh : "doesn't exist";
    });
  }
}
