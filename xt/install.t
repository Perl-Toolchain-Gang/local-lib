use strict;
use warnings;
use Test::More;
use Capture::Tiny qw(capture_merged);
use File::Spec;
use File::Path qw(mkpath);
use Cwd;
use Config;

use lib 't/lib';
use TempDir;

use local::lib ();

delete @ENV{
  'PERL_MM_OPT',
  'PERL_MB_OPT',
  'PERL_LOCAL_LIB_ROOT',
  grep /^MAKE/, keys %ENV
};

my @dirs = (
  'plain',
  'with space',
  'with\backslash',
  'with space\and-bs',
);

my %dist_types = (
  EUMM => sub {
    open my $fh, '>', 'Makefile.PL' or die "can't create Makefile.PL: $!";
    binmode $fh;
    print $fh 'use ExtUtils::MakeMaker; WriteMakefile( NAME => "EUMM" );';
    close $fh;
    system(local::lib::_perl, 'Makefile.PL') && die "Makefile.PL failed";
    system($Config{make}, 'install') && die "$Config{make} install failed";
  },
  MB => sub {
    open my $fh, '>', 'Build.PL' or die "can't create Build.PL: $!";
    binmode $fh;
    print $fh <<END_BUILD;
use Module::Build;
Module::Build->new(
  module_name       => "MB",
  dist_version      => 1,
  license           => "perl",
)->create_build_script;
END_BUILD
    close $fh;
    system(local::lib::_perl, 'Build.PL') && die "Build.PL failed";
    system(local::lib::_perl, 'Build', 'install') && die "Build install failed";
  },
);

plan tests => @dirs * keys(%dist_types) * 2;

my $orig_dir = cwd;
for my $dir_base (@dirs) {
  for my $dist_type (sort keys %dist_types) {
    chdir $orig_dir;
    local @ENV{
      'PERL_MM_OPT',
      'PERL_MB_OPT',
      'PERL_LOCAL_LIB_ROOT',
      grep /^MAKE/, keys %ENV
    };
    local $ENV{PERL5LIB} = $ENV{PERL5LIB};
    my $temp = mk_temp_dir("install-$dist_type");
    my $ll_dir = "$dist_type-$dir_base";
    my $ll = "$temp/$ll_dir";
    mkpath(File::Spec->canonpath($ll));

    local::lib->import($ll, '--quiet');

    my $dist_dir = mk_temp_dir("source-$dist_type");
    chdir $dist_dir;
    mkdir 'lib';
    open my $fh, '>', "lib/$dist_type.pm";
    binmode $fh;
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
chdir $orig_dir;
