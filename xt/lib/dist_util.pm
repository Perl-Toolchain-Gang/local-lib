package dist_util;
use strict;
use warnings;

use File::Copy qw(copy);
use File::Find ();
use File::Spec ();
use File::Temp ();
use IPC::Open3;
use File::Basename qw(dirname basename fileparse);
use Cwd qw(cwd);
use File::Path qw(mkpath rmtree);
use Config;
use IO::File;

use Exporter; *import = \&Exporter::import;
our @EXPORT = qw(make_dist make_dist_dir cap_system tar writefile);

sub writefile {
  my ($file, $content) = @_;
  my $fh;
  if ($file =~ /\.gz$/) {
    require IO::Compress::Gzip;
    $fh = IO::Compress::Gzip->new($file);
  }
  else {
    $fh = IO::File->new($file, '>:raw');
  }
  $fh->print($content);
  $fh->close;
  undef $fh;
  1;
}

sub cap_system {
  my (@cmd) = @_;
  my $failed;
  open my $stdin, '<', File::Spec->devnull;
  my $pid = open3 $stdin, my $stdout, undef, @cmd;
  my $out = do { local $/; <$stdout> };
  close $stdout;
  waitpid $pid, 0;
  my $status = $?;
  die "failed running [@cmd] (status $status):\n$out\n"
    if $status;
  return $out;
}

sub make_dist_dir {
  my $dist_dir = shift || File::Temp::tempdir('local-lib-dist-XXXXX', TMPDIR => 1);
  copy 'Makefile.PL', "$dist_dir/Makefile.PL";
  { open my $fh, '>', "$dist_dir/META.yml"; }
  File::Find::find({ no_chdir => 1, wanted => sub {
    my $dest = "$dist_dir/$_";
    if (-d) {
      mkdir $dest;
    }
    else {
      copy $_, $dest;
    }
  }}, 'inc', 'lib');
  return $dist_dir;
}

sub make_dist {
  my $dist = shift;
  my $distvname = basename($dist);
  $distvname =~ s/\..*//;
  $dist = File::Spec->rel2abs($dist);
  my $dist_dir = make_dist_dir();
  my $cwd = cwd;
  chdir $dist_dir;
  cap_system $^X, 'Makefile.PL';
  cap_system $Config{make}, 'manifest';
  cap_system $Config{make}, 'distdir', "DISTVNAME=$distvname";
  tar($distvname, $dist);
  chdir $cwd;
  rmtree $dist_dir;
  return $dist;
}

sub tar {
  require Archive::Tar;
  my $dir = shift;
  my $basename = basename($dir);
  my $parent = dirname($dir);
  my $tar = shift || do {
    local $^W;
    (File::Temp::tempdir(
        "$basename-XXXXX",
        SUFFIX => '.tar.gz',
        TMPDIR => 1,
        OPEN => 0,
    ))[1];
  };
  my $cwd = cwd;
  chdir $parent;
  my @files;
  File::Find::find({no_chdir => 1, wanted => sub {
    push @files, $_;
  }}, $basename);
  Archive::Tar->create_archive(
    $tar,
    Archive::Tar::COMPRESS_GZIP(),
    @files,
  );
  chdir $cwd;
  return $tar;
}

1;
