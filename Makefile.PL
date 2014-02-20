use strict;
use warnings FATAL => 'all';

my %META = (
  name => 'local-lib',
  license => 'perl_5',
  prereqs => {
    configure => { requires => {
    } },
    build => { requires => {
    } },
    test => { requires => {
      'Test::More'  => 0,
    } },
    runtime => { requires => {
      'perl'                => 5.006,
      'ExtUtils::MakeMaker' => '6.74', # version PERL_MM_OPT is shell parsed
      'ExtUtils::Install'   => '1.43', # version INSTALL_BASE was added
      'Module::Build'       => '0.36', # PERL_MB_OPT
      'CPAN'                => '1.82', # sudo support + CPAN::HandleConfig
    } },
    develop   => { requires => {
      $] >= 5.010 ? ('Test::CPAN::Changes' => 0) : (),
      'Test::EOL'     => 0,
      'Test::NoTabs'  => 0,
      'Test::Pod'     => 0,
      'Capture::Tiny' => 0,
    } },
  },
  resources => {
    repository => {
      url => 'git://github.com/Perl-Toolchain-Gang/local-lib',
      web => 'https://github.com/Perl-Toolchain-Gang/local-lib',
      type => 'git',
    },
    x_IRC => 'irc://irc.perl.org/#local-lib',
    bugtracker => {
      web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=local-lib',
      mailto => 'bug-local-lib@rt.cpan.org',
    },
    license => [ 'http://dev.perl.org/licenses/' ],
  },
);

my %MM_ARGS = ();

##############################################################################

# Solaris (and possibly other Unices) have a tar in /usr/bin that, among
# other things, does not understand @LongLink. This can cause
# extraction to look like it succeeded, but it actually failed (because
# the error message for the @LongLink failure scrolled offscreen).
# Therefore, given the fact that GNU tar is the most widespread tar available,
# and it actually supports the feature we want (I'd bet it originated in GNU
# tar, but I digress), we'll look for GNU tar. If we don't find it, and the
# user hasn't pointed us to a suitable tar, we'll bomb and tell them what to
# do.
#
require File::Spec;
unless (exists $ENV{PERL_LL_TAR} ? -x $ENV{PERL_LL_TAR}
  : $^O eq 'solaris'
    ? (grep -x,
      map File::Spec->catfile($_, 'gtar'),
      File::Spec->paths)
  : 1) {
  die <<'DEATH';
You are using Solaris (or another traditional Unix) that does not provide a sane
tar, capable of dealing with the output of GNU tar. Please either set the
PERL_LL_TAR environment variable to the location of a version of tar that
understands the @LongLink convention or put a binary named gtar somewhere on
your PATH.
DEATH
}

# watch out for fancy dashes. these can wind up in our @ARGV if the user is
# copypasting the bootstrap command from the POD displayed e.g. by perldoc
# on a Mac OS X terminal. since no software recognizes and handles these
# dashes, it's better to die loudly telling the user exactly what happened
# so they don't make the same mistake again rather than being the only
# program in the universe that works with them.
# the fancy dash is U+2212 or \xE2\x88\x92
if(grep { /\xE2\x88\x92/ || /\x{2212}/ } @ARGV) {
  die <<'DEATH';
WHOA THERE! It looks like you've got some fancy dashes in your commandline!
These are *not* the traditional -- dashes that software recognizes. You
probably got these by copy-pasting from the perldoc for this module as
rendered by a UTF8-capable formatter. This most typically happens on an OS X
terminal, but can happen elsewhere too. Please try again after replacing the
dashes with normal minus signs.
DEATH
}

my $bootstrapping;
my $disable_manpages;
if (my ($x) = grep { /^--bootstrap(?:=.*)?$/ } @ARGV) {
  (my $path = $x) =~ s/^.*?=//;
  @ARGV = grep { !/^--bootstrap(?:=.*)?$/ } @ARGV;
  if(my ($x) = grep { /^--no-manpages$/ } @ARGV) {
    $disable_manpages = 1;
    @ARGV = grep { !/^--no-manpages/ } @ARGV;
  }

  {
    local @INC = @INC;
    unshift(@INC, 'lib');
    require local::lib;
  }

  local::lib->import($path || ());
  $bootstrapping = 1;
}

my $requires = $META{prereqs}{runtime}{requires};
$requires = { %$requires } unless -f 'META.yml' or $ENV{AUTOMATED_TESTING};
if ($ENV{PERL5_CPANM_IS_RUNNING}) {
  delete $requires->{CPAN};
}
for my $module (grep { $_ ne 'perl' } keys %$requires) {
  open my $olderr, '>&', \*STDERR or die "Can't dup STDERR: $!";
  open STDERR, '>', File::Spec->devnull or die "Can't open /dev/null: $!";
  if (system $^X, "-m$module", '-e1') {
    delete $requires->{$module};
  }
  elsif (! system $^X, "-M$module $requires->{$module}", '-e1') {
    delete $requires->{$module};
  }
  open STDERR, '>&', $olderr or die "Can't dup to STDERR: $!";
}

if ($bootstrapping) {
  my @modules = grep $requires->{$_},
    qw(ExtUtils::MakeMaker ExtUtils::Install Module::Build CPAN);

  no warnings 'once';
  *MY::postamble = sub {
    <<"END";
PERL     += -I\$(INSTALLPRIVLIB)
FULLPERL += -I\$(INSTALLPRIVLIB)
END
  };

  local $ENV{PERL_AUTOINSTALL_PREFER_CPAN} = 1;
  local $ENV{PERL_MM_USE_DEFAULT} = 1;

  my @cpan_command = map qq{force(q[install],q[$_]);}, @modules;

  if (@cpan_command || $disable_manpages) {
    system($^X, '-Minc::ConfigCPAN', '-', 'configure');
  }
  if (@cpan_command) {
    system($^X, '-MCPAN', '-e', $_)
      for @cpan_command;
  }
  if (grep { $_ eq 'CPAN' } @modules ) {
    system($^X, '-MCPAN', '-e', 'CPAN::Config->load;CPAN::Config->commit;');
  }
  if ($disable_manpages) {
    system($^X, '-Minc::ConfigCPAN', '-', 'disable_manpages');
  }
}

if (!$ENV{PERL5_CPANM_IS_RUNNING}
    and my $cpan_req = $META{prereqs}{runtime}{CPAN}) {
  my $status = system $^X, '-Minc::ConfigCPAN', '-', 'check', $cpan_req;
  exit $status
    if $status;
}

##############################################################################
require ExtUtils::MakeMaker;
ExtUtils::MakeMaker->import;

(do 'maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta_works      = $eumm_version >= 6.57_07;
my $mymeta            = $eumm_version >= 6.57_02;
my $has_test_requires = $eumm_version >= 6.63_03;

my %configure_deps = %{$META{prereqs}{configure}{requires}};
my %build_deps     = %{$META{prereqs}{build}{requires}};
my %test_deps      = %{$META{prereqs}{test}{requires}};
my %run_deps       = %{$META{prereqs}{runtime}{requires}};

my $min_perl_version = delete $run_deps{perl};

if (not $has_test_requires) {
  %build_deps = (%build_deps, %test_deps);
  %test_deps = ();
}
if (not $mymeta_works) {
  %run_deps = (%run_deps, %build_deps);
  %build_deps = ();
}

(my $module_name = $META{name}) =~ s/-/::/g;
(my $module_file = "lib/$module_name.pm") =~ s{::}{/}g;

WriteMakefile(
  NAME => $module_name,
  VERSION_FROM => $module_file,
  LICENSE => $META{license},

  $eumm_version >= 6.47_01 && $min_perl_version
    ? ( MIN_PERL_VERSION    => $min_perl_version ) : (),
  $eumm_version >= 6.51_03
    ? ( CONFIGURE_REQUIRES  => \%configure_deps ) : (),
  $eumm_version >= 6.55_01
    ? ( BUILD_REQUIRES      => \%build_deps ) : (),
  $eumm_version >= 6.63_03
    ? ( TEST_REQUIRES       => \%test_deps ) : (),
  PREREQ_PM => \%run_deps,

  ($mymeta && !$mymeta_works ? (NO_MYMETA => 1) : ()),
  -f 'META.yml' ? () : (META_ADD => { 'meta-spec' => { version => 2 }, %META }),

  %MM_ARGS,
);
