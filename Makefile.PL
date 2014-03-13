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
    develop   => {
      requires => {
        'Test::EOL'     => 0,
        'Test::NoTabs'  => 0,
        'Test::Pod'     => 0,
        'Capture::Tiny' => 0,
        'Test::More'    => 0.81_01,
      },
      recommends => {
        'Test::CPAN::Changes' => 0,
      },
    },
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
      File::Spec->path)
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
  @ARGV = grep { !/^--bootstrap(?:=.*)?$/ } @ARGV;
  my ($path) = $x =~ /^--bootstrap(?:=(.*))?$/;
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

my $requires = $MM_ARGS{PREREQ_PM} = { %{$META{prereqs}{runtime}{requires}} };
if ($ENV{PERL5_CPANM_IS_RUNNING}) {
  $requires->{CPAN} = undef;
}
for my $module (grep { $_ ne 'perl' } keys %$requires) {
  my $need_v = $requires->{$module} or next;
  my $res = system($^X, '-Minc::CheckVersion', '-', $module, $need_v);
  $res >>= 8;
  if ($res == 0 || $res == 1) {
    $requires->{$module} = undef;
  }
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

if (!$ENV{PERL5_CPANM_IS_RUNNING}) {
  my $status = system $^X, '-Minc::ConfigCPAN', '-', 'check',
    $META{prereqs}{runtime}{requires}{CPAN};
  exit $status
    if $status;
}

##############################################################################
require ExtUtils::MakeMaker;
(do 'maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta        = $eumm_version >= 6.57_02;
my $mymeta_broken = $mymeta && $eumm_version < 6.57_07;

($MM_ARGS{NAME} = $META{name}) =~ s/-/::/g;
($MM_ARGS{VERSION_FROM} = "lib/$MM_ARGS{NAME}.pm") =~ s{::}{/}g;
$MM_ARGS{LICENSE} = $META{license}
  if $eumm_version >= 6.30;
$MM_ARGS{NO_MYMETA} = 1
  if $mymeta_broken;
$MM_ARGS{META_ADD} = { 'meta-spec' => { version => 2 }, %META }
  unless -f 'META.yml';

for (qw(configure build test runtime)) {
  my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
  my $r = $MM_ARGS{$key} = {
    %{$META{prereqs}{$_}{requires}},
    %{delete $MM_ARGS{$key} || {}},
  };
  defined $r->{$_} or delete $r->{$_} for keys %$r;
}

$MM_ARGS{MIN_PERL_VERSION} = delete $MM_ARGS{PREREQ_PM}{perl} || 0;

delete $MM_ARGS{MIN_PERL_VERSION}
  if $eumm_version < 6.47_01;
$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
  if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
  if $eumm_version < 6.55_01;
delete $MM_ARGS{CONFIGURE_REQUIRES}
  if $eumm_version < 6.51_03;

ExtUtils::MakeMaker::WriteMakefile(%MM_ARGS);
