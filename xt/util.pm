package xt::util;
use strict;
use warnings;

use File::Copy qw(copy);
use File::Find ();
use File::Temp ();

use Exporter; *import = \&Exporter::import;
our @EXPORT = qw(make_dist_dir);

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

1;
