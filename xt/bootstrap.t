use strict;
use warnings;
BEGIN {
  if (@ARGV && $ARGV[0] eq '--check-version') {
    my $module = $ARGV[1];
    (my $file = "$module.pm") =~ s{::}{/}g;
    eval {
      require $file;
      my $version = do { no strict; ${"${module}::VERSION"} };
      print eval $version;
    };
    exit;
  }
}

use Test::More;
use File::Temp;
use File::Spec;
use local::lib ();

delete $ENV{PERL5LIB};
delete $ENV{PERL_LOCAL_LIB_ROOT};
delete $ENV{PERL_MM_OPT};
delete $ENV{PERL_MB_OPT};

#my @ll_path = File::Spec->splitpath($INC{'local/lib.pm'});
#my @ll_dir = File::Spec->splitdir($ll_path[1]);
#my $ll_dir = File::Spec->catpath($ll_path[0], File::Spec->catdir(@ll_dir[0 .. $#_-1]), '');

sub check_version {
  my $module = shift;
  my $version = `$^X $0 --check-version $module`;
  chomp $version;
  length $version ? $version : undef;
}

my @modules = (
  [ 'ExtUtils::MakeMaker' => 6.74 ],
  [ 'ExtUtils::Install'   => 1.43 ],
  [ 'Module::Build'       => 0.36 ],
  [ 'CPAN'                => 1.82 ],
);
plan tests => 1+@modules;

for my $module (@modules) {
  my $version = check_version($module->[0]);
  if ($version && $version >= $module->[1]) {
    warn "Can't test bootstrap of $module->[0], version $version already meets requirement of $module->[1]\n";
  }
}

$ENV{HOME} = my $home = File::Temp::tempdir( CLEANUP => 1 );
local::lib->import;

system($^X, 'Makefile.PL', '--bootstrap');
is $?, 0, 'Makefile.PL ran successfully';

for my $module (@modules) {
  my $version = check_version($module->[0]);
  cmp_ok $version, '>=', $module->[1], "bootstrap installed new enough $module->[0]";
}
