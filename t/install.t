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
    open my $fh, '>', 'Makefile.PL' or die "can't create Makefile.PL: $!";
    print $fh 'use ExtUtils::MakeMaker; WriteMakefile( NAME => "EUMM" );';
    close $fh;
    system($^X, 'Makefile.PL') && die "Makefile.PL failed";
    system($Config{make}, 'install') && die "$Config{make} install failed";
  },
  MB => sub {
    open my $fh, '>', 'Build.PL' or die "can't create Build.PL: $!";
    print $fh <<END_BUILD;
use Module::Build;
Module::Build->new(
  module_name       => "MB",
  dist_version      => 1,
  license           => "perl",
)->create_build_script;
END_BUILD
    close $fh;
    system($^X, 'Build.PL') && die "Build.PL failed";
    system($^X, 'Build', 'install') && die "Build install failed";
  },
);

plan tests => @dirs * keys(%dist_types) * 2;

my $orig_dir = cwd;
for my $dir_base (@dirs) {
  for my $dist_type (sort keys %dist_types) {
    chdir $orig_dir;
    my $temp = mk_temp_dir("install-$dist_type-XXXXX");
    my $ll_dir = "$dist_type-$dir_base";
    my $ll = "$temp/$ll_dir";
    mkpath(File::Spec->canonpath($ll));

    local::lib->import($ll);

    my $dist_dir = mk_temp_dir("source-$dist_type-XXXXX");
    chdir $dist_dir;
    mkdir 'lib';
    open my $fh, '>', "lib/$dist_type.pm";
    print $fh '1;';
    close $fh;

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
