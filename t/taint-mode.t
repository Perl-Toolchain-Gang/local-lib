#
# t/taint-mode.t: checks that local::lib sets up @INC correctly when
# included in a script that has taint mode on, and is executing in an
# environment in which local::lib has already been loaded.
#

use strict;
use warnings;
use Cwd; # load before anything else to work around ActiveState bug
use Test::More tests => 4;
use lib 't/lib';
use TempDir;
use File::Basename qw(basename dirname);
use File::Spec;
use IPC::Open3;
use Config;

use lib 't/lib'; use TempDir;

my @INC_CLEAN = @INC;

my $perl = local::lib::_perl;

my $dir1 = mk_temp_ll_dir('used_in_taint');
my $dir2 = mk_temp_ll_dir('not_used_in_taint');

# Set up local::lib environment using our temp dir
require local::lib;
local::lib->import($dir1);
local::lib->import($dir2);

{
  # Create a script that has taint mode turned on, and tries to use a
  # local lib to the same temp dir.
  my ($fh, $filename) = mk_temp_file;
  binmode $fh;

  print $fh <<"EOM";
#!/usr/bin/perl -T
use strict; use warnings;
use local::lib "\Q$dir1\E";
print "\$_\\n" for \@INC;
EOM
  close $fh;

  open my $in, '<', File::Spec->devnull
    or die "can't open null input: $!";
  my $pid = open3($in, my $out, undef, $perl, map("-I$_", @INC_CLEAN), '-T', $filename);
  binmode $out;
  my @libs = <$out>;
  s/[\r\n]*\z// for @libs;
  close $out;
  waitpid $pid, 0;
  is $?, 0, 'test script ran without error';

  my $dir1_lib = local::lib->install_base_perl_path($dir1);
  ok grep($_ eq $dir1_lib, @libs),
    'local::lib used in taint script added to @INC'
    or diag "searched for '$dir1_lib' in: ", join(', ', map "'$_'", @libs);

  my $dir2_lib = local::lib->install_base_perl_path($dir2);
  ok !grep($_ eq $dir2_lib, @libs),
    'local::lib not used used in taint script not added to @INC'
    or diag "searched for '$dir2_lib' in: ", join(', ', map "'$_'", @libs);
}

{
  my ($fh, $filename) = mk_temp_file;
  binmode $fh;

  print $fh <<'EOM';
#!/usr/bin/perl -T
use strict; use warnings;
use local::lib ();
print local::lib::_cwd();
EOM
  close $fh;

  open my $in, '<', File::Spec->devnull
    or die "can't open null input: $!";
  open my $err, '>', File::Spec->devnull
    or die "can't open null output: $!";
  my $out;
  my $pid = open3($in, $out, $err, $perl, map("-I$_", @INC_CLEAN), '-T', $filename);
  binmode $out;
  my $cwd = do { local $/; <$out> };
  my $errout = do { local $/; <$err> };
  $cwd =~ s/[\r\n]*\z//;
  $cwd = File::Spec->canonpath($cwd);
  is $cwd, File::Spec->canonpath(Cwd::getcwd()), 'reimplemented cwd matches standard cwd'
    or diag $errout;
}
