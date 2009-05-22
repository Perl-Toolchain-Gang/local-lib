#!/usr/bin/perl
# contributed by hdp@cpan.org

use strict;
use warnings;
use CPAN;
use Cwd;
use File::Spec;
my $target = Cwd::abs_path($ENV{TARGET})
  or die "set \$ENV{TARGET} to your desired local::lib dir\n";

my $mod = CPAN::Shell->expand(Module => "local::lib");
$mod->get;
my $dir = CPAN::Shell->expand(Distribution => $mod->cpan_file)->dir;
chdir($dir);
my $make = $CPAN::Config->{make};
system($^X, 'Makefile.PL',"--bootstrap=$target") && exit 1;
system($make, 'test') && exit 1;
system($make, 'install') && exit 1;
