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

sub check_version {
  my ($perl, $module) = @_;
  my $version = `$perl $0 --check-version $module`;
  chomp $version;
  length $version ? $version : undef;
}

use Test::More 0.81_01;
use IPC::Open3;
use File::Temp;
use File::Spec;
use Parse::CPAN::Meta;
use local::lib ();

my @perl;
my $force;
while (@ARGV) {
  my $arg = shift @ARGV;
  if ($arg =~ /^--perl(?:=(.*))$/) {
    push @perl, ($1 || shift @ARGV);
  }
  elsif ($arg eq '-f') {
    $force = 1;
  }
  else {
    warn "unrecognized option: $arg\n";
  }
}

plan skip_all => 'this test will overwrite Makefile.  use -f to force.'
  if -e 'Makefile' && !$force;

@perl = $^X
  unless @perl;

my %modules = (
  'ExtUtils::MakeMaker' => 6.74,
  'ExtUtils::Install'   => 1.43,
  'Module::Build'       => 0.36,
  'CPAN'                => 1.82,
);

plan tests => @perl * (1+keys %modules);

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
  local $ENV{HOME} = my $home = File::Temp::tempdir('local-lib-home-XXXXX', CLEANUP => 1, TMPDIR => 1);

  diag "testing bootstrap with $perl";
  my %old_versions;
  for my $module (sort keys %modules) {
    my $version = check_version($perl, $module);
    $old_versions{$module} = $version;
    if ($version && $version >= $modules{$module}) {
      diag "Can't test bootstrap of $module, version $version already meets requirement of $modules{$module}";
    }
  }

  my $ll = File::Spec->catdir($home, 'local-lib');

  open my $null_in, '<', File::Spec->devnull;
  my $pid = open3 $null_in, my $out, undef, $perl, 'Makefile.PL', '--bootstrap='.$ll;
  while (my $line = <$out>) {
    note $line;
  }
  waitpid $pid, 0;

  is $?, 0, 'Makefile.PL ran successfully'
    or diag $out;

  my $meta = Parse::CPAN::Meta->load_file('MYMETA.yml');

  local::lib->setup_env_hash_for($ll);

  for my $module (sort keys %modules) {
    SKIP: {
      my $need_version = $meta->{requires}{$module}
        or skip "$module not needed for $perl", 1;
      my $version = check_version($perl, $module);
      if (defined $old_versions{$module}) {
        cmp_ok $version, '>=', $modules{$module}, "bootstrap upgraded to new enough $module"
          or diag "PERL5LIB: $ENV{PERL5LIB}";
      }
      else {
        is $version, undef, "bootstrap didn't install new module $module";
      }
    }
  }
}

unlink 'Makefile';
