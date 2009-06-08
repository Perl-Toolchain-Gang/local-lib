#!/usr/bin/perl
# contributed by hdp@cpan.org

use strict;
use warnings;
use CPAN;
use Cwd;
use File::Spec;
my $target = $ENV{TARGET} ? Cwd::abs_path($ENV{TARGET}) : undef;

my $mod = CPAN::Shell->expand(Module => "local::lib");
$mod->get;
my $dir = CPAN::Shell->expand(Distribution => $mod->cpan_file)->dir;
chdir($dir);
my $make = $CPAN::Config->{make};
my $bootstrap = $target ? "--bootstrap=$target" : "--bootstrap";
system($^X, 'Makefile.PL', $bootstrap) && exit 1;
system($make, 'test') && exit 1;
system($make, 'install') && exit 1;
