use strict;
use warnings;

use lib 't/lib', 'xt/lib';
use Test::More 0.81_01;
use IPC::Open3;
use TempDir;
use File::Spec;
use File::Path qw(rmtree);
use File::Basename qw(dirname);
use local::lib ();
use ExtUtils::MakeMaker;
use Cwd qw(cwd);
use dist_util;

sub check_version {
  my ($perl, $module) = @_;
  my @inc = `$perl -le "print for \@INC"`;
  chomp @inc;
  (my $file = "$module.pm") =~ s{::}{/}g;
  ($file) = grep -e, map { "$_/$file" } @inc;
  return undef
    unless $file;
  my $version = MM->parse_version($file);
  eval $version;
}

my @perl;
my $verbose;
while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg eq '-v') {
    $verbose = 1;
  }
  elsif ($arg eq '--') {
    push @perl, @ARGV;
    @ARGV = ();
  }
  elsif ($arg =~ /^-/) {
    warn "unrecognized option: $arg\n";
  }
  else {
    push @perl, $arg;
  }
}

my $dist_dir = make_dist_dir;
my $cwd = cwd;
END {
  chdir $cwd;
  rmtree $dist_dir;
}

chdir $dist_dir;

@perl = local::lib::_perl
  unless @perl;

my %modules = (
  'ExtUtils::MakeMaker' => '7.00', # version INSTALL_BASE taken as string, not shell
  'ExtUtils::Install'   => '1.43', # version INSTALL_BASE was added
  'Module::Build'       => '0.36', # PERL_MB_OPT
  'CPAN'                => '1.82', # sudo support + CPAN::HandleConfig
);

plan tests => @perl * 2 * (2+2*keys %modules);

for my $perl (@perl) {
  local @INC = @INC;
  local $ENV{AUTOMATED_TESTING} = 1;
  local $ENV{PERL5LIB};
  local $ENV{PERL_LOCAL_LIB_ROOT};
  local $ENV{PERL_MM_OPT};
  local $ENV{PERL_MB_OPT};
  delete $ENV{PERL5LIB};
  delete $ENV{PERL_LOCAL_LIB_ROOT};
  delete $ENV{PERL_MM_OPT};
  delete $ENV{PERL_MB_OPT};

  diag "testing bootstrap with $perl";
  my %old_versions;
  for my $module (sort keys %modules) {
    my $version = check_version($perl, $module);
    $old_versions{$module} = $version;
    if ($version && $version >= $modules{$module}) {
      diag "Can't test bootstrap of $module, version $version already meets requirement of $modules{$module}";
    }
  }

  my $home_base = mk_temp_dir('home-base');

  for my $home_tmpl ('home', 'spaces in home') {
    delete $ENV{PERL5LIB};
    delete $ENV{PERL_LOCAL_LIB_ROOT};
    delete $ENV{PERL_MM_OPT};
    delete $ENV{PERL_MB_OPT};
    local $ENV{HOME} = my $home = "$home_base/$home_tmpl";

    my $ll = File::Spec->catdir($home, 'local-lib');
    note "local::lib dir is $ll";

    unlink 'MYMETA.yml';
    unlink 'Makefile';

    open my $null_in, '<', File::Spec->devnull;
    my $pid = open3 $null_in, my $out, undef,
      $perl, 'Makefile.PL', '--bootstrap='.$ll, '--no-manpages';
    while (my $line = <$out>) {
      note $line
        if $verbose || $line =~ /^Running |^\s.* -- (?:NOT OK|OK|NA|TIMED OUT)$/;
    }
    waitpid $pid, 0;

    is $?, 0, 'Makefile.PL ran successfully';

    ok -e 'Makefile', 'Makefile created';

    my $prereqs = {};
    open my $fh, '<', 'Makefile'
      or die "Unable to open Makefile: $!";

    while (<$fh>) {
      last if /MakeMaker post_initialize section/;
      my ($p) = m{^[\#]\s+PREREQ_PM\s+=>\s+(.+)}
        or next;

      while ( $p =~ m/(?:\s)([\w\:]+)=>(?:q\[(.*?)\]|undef),?/g ) {
        $prereqs->{$1} = $2;
      }
    }
    close $fh;

    local::lib->setup_env_hash_for($ll);

    for my $module (sort keys %modules) {
      my $version = check_version($perl, $module);
      my $old_v = $old_versions{$module};
      my $want_v = $modules{$module};
      if (defined $old_v) {
        is $prereqs->{$module}, ($old_v >= $want_v ? undef : $want_v),
          "prereqs correct for $module";
        cmp_ok $version, '>=', $want_v, "bootstrap upgraded to new enough $module"
          or diag "PERL5LIB: $ENV{PERL5LIB}";
      }
      else {
        ok !exists $prereqs->{$module},
          "$module not listed as prereq";
        is $version, undef, "bootstrap didn't install new module $module";
      }
    }
  }
}
