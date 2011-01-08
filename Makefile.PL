use strict;
use warnings;
use File::Spec;
use Cwd;
use vars qw($bootstrapping $bootstrapping_args $no_manpages);
use Config;

# Solaris (and possibly other Unices) have a tar in /usr/bin that, among
# other things, does not understand @LongLink. This can cause 
# extraction to look like it succeeded, but it actually failed (because
# the error message for the @LongLink failure scrolled offscreen).
# Therefore, given the fact that GNU tar is the most widespread tar available,
# and it actually supports the feature we want (I'd bet it originated in GNU
# tar, but I digress), we'll look for GNU tar. If we don't find it, and the
# user hasn't pointed us to a suitable tar, we'll bomb and tell them what to
# do.

my $have_gtar = 0;
if($^O eq 'solaris') {
  $have_gtar = 0;
  for my $env_path (split /:/, $ENV{PATH}) {
    $have_gtar = 1 if -x File::Spec->catfile($env_path, 'gtar');
  }
} else {
  $have_gtar = 1;
}
if(exists $ENV{PERL_LL_TAR}) {
  $have_gtar ||= -x $ENV{PERL_LL_TAR};
}

die <<'DEATH' unless $have_gtar;
You are using Solaris (or another traditional Unix) that does not provide a sane
tar, capable of dealing with the output of GNU tar. Please either set the
PERL_LL_TAR environment variable to the location of a version of tar that
understands the @LongLink convention or put a binary named gtar somewhere on
your PATH.
DEATH

my $cwd;
BEGIN {
  $cwd = Cwd::cwd();
  # watch out for fancy dashes. these can wind up in our @ARGV if the user is
  # copypasting the bootstrap command from the POD displayed e.g. by perldoc
  # on a Mac OS X terminal. since no software recognizes and handles these
  # dashes, it's better to die loudly telling the user exactly what happened
  # so they don't make the same mistake again rather than being the only
  # program in the universe that works with them.
  if(grep { /−/ } @ARGV) {
      die <<'DEATH';
WHOA THERE! It looks like you've got some fancy dashes in your commandline!
These are *not* the traditional -- dashes that software recognizes. You
probably got these by copy-pasting from the perldoc for this module as
rendered by a UTF8-capable formatter. This most typically happens on an OS X
terminal, but can happen elsewhere too. Please try again after replacing the
dashes with normal minus signs.
DEATH
  }
  if (my ($x) = grep { /^--bootstrap(?:=.*)?$/ } @ARGV) {
    @ARGV = grep { !/^--bootstrap(?:=.*)?$/ } @ARGV;
    $bootstrapping = 1;
    if(my ($x) = grep { /^--no-manpages/ } @ARGV) {
      $no_manpages = 1;
      @ARGV = grep { !/^--no-manpages/ } @ARGV;
    }
    my ($path) = $x =~ /^--bootstrap(?:=(.*))?$/;
    my @args = $path ? $path : ();

    {
      local @INC = @INC;
      unshift(@INC, 'lib');
      require local::lib;
    }

    local::lib->import(@args);

    my @libs = map { "-I$_" } split $Config{path_sep}, $ENV{PERL5LIB};
    $bootstrapping_args = "@libs";
    push(@ARGV,$ENV{PERL_MM_OPT});
    push(@ARGV, @libs);

    # <mst> GODDAMN makepl_arg INSTALLDIRS=site
    # <mst> we must set PERL_AUTOINSTALL_PREFER_CPAN too
    $ENV{PERL_AUTOINSTALL_PREFER_CPAN} = 1;

    system($^X, '-MExtUtils::MakeMaker 6.31', '-e1');
    my $eumm = $? >> 8;

    system($^X, '-MExtUtils::Install 1.43', '-e1');
    my $eui = $? >> 8;

    system($^X, '-MModule::Build 0.36', '-e1');
    my $mb = $? >> 8;

    system($^X, '-MCPAN 1.82', '-e1');
    my $cpan = $? >> 8;
    my $cpan_command = '';

    my $did_cpan_config = 0;
    my $cpan_config_command =
      'my $done; require ExtUtils::MakeMaker;
       my $orig = ExtUtils::MakeMaker->can("prompt");
       *ExtUtils::MakeMaker::prompt = sub ($;$) {
         if (!$done && $_[0] =~ /manual configuration/) {
           $done++;
           return "no";
         }
         return $orig->(@_);
       };
       # not yet -- apeiron, 2010-03-10 
       #$CPAN::Config->{urllist} = ["http://cpan.shadowcatprojects.net"];
       # <mst> all bootstrapped fine on one DH account
       # <mst> on another, it tries to install man stuff into /usr/local
       # <mst> cannot for the life of me figure out why
       # <mst> (same fucking server as well)
       # <mst> GOT THE BASTARD
       # <mst> ExtUtils::ParseXS uses Module::Build
       # <mst> but Module::Build depends on it
       # <mst> so you need to set prefer_installer MM
       # <mst> so cpan uses EU::ParseXS Makefile.PL
       # <mst> since we already got EUMM, *that* works
       $CPAN::Config->{prefer_installer} = "EUMM";
       CPAN::Config->load;
       unless ($done || -w $CPAN::Config->{keep_source_where}) {
         my $save = $CPAN::Config->{urllist};
         delete @{$CPAN::Config}{keys %$CPAN::Config};
         $CPAN::Config->{urllist} = $save;
         CPAN::Config->init;
       }';

    $ENV{PERL_MM_USE_DEFAULT} = 1;

    # XXX - remove the force on EUMM once its test suite survive PERL_MM_OPT

    if ($eumm) { # non-zero exit
      $cpan_command .= 'force("install","ExtUtils::MakeMaker"); ';
    }
    if ($eui) {
      $cpan_command .= 'install("ExtUtils::Install"); ';
    }
    if ($mb) {
      $cpan_command .= 'install("Module::Build"); ';
    }
    if ($cpan) {
      $cpan_command .= 'force("install","CPAN"); ';
    }
    if(length $cpan_command) {
      system($^X, '-MCPAN', '-e', $cpan_config_command);
      $did_cpan_config++;
      system($^X, '-MCPAN', '-e', $cpan_command);
    }
    if ($cpan) {
      system($^X, '-MCPAN', '-e', 'CPAN::Config->load; CPAN::Config->commit;');
    }
    if($no_manpages) {
      # if we call this code directly, the changes get written to
      # $BOOTSTRAP/lib/perl5/CPAN/Config.pm, not where the user expects them to
      # be in their ~/.cpan/CPAN/MyConfig.pm.
      system($^X, '-MCPAN', '-e', $cpan_config_command)
        unless $did_cpan_config;
      system($^X, '-MCPAN',
        '-e', 
        q[CPAN::HandleConfig->load;],
        '-e', 
        q[$CPAN::Config->{makepl_arg}  = ] . 
          q['INSTALLMAN1DIR=none INSTALLMAN3DIR=none';],
        '-e',
        q[$CPAN::Config->{buildpl_arg} = ] .
          q['--install_path libdoc="" --install_path bindoc=""';],
        '-e',
        q[CPAN::Config->commit;],
      );
    }

    chdir($cwd);
  }
}

use inc::Module::Install;

name 'local-lib';
all_from 'lib/local/lib.pm';

requires 'ExtUtils::MakeMaker' => '6.31'; # version INSTALL_BASE was added
requires 'ExtUtils::Install' => '1.43'; # ditto
requires 'Module::Build' => '0.36'; # PERL_MB_OPT
my $required_CPAN = '1.82';
requires 'CPAN' => $required_CPAN; # sudo support + CPAN::HandleConfig

# No, really. See
# https://rt.cpan.org/Public/Bug/Display.html?id=23735
# for why CPAN now sets the CPANPLUS env var.
# trouble is this means we can't auto_install(_now) CPAN itself
# without this beautiful hack

my $no_cpanplus_env = !exists $ENV{PERL5_CPANPLUS_IS_RUNNING};
my $no_cpan_env = !exists $ENV{PERL5_CPAN_IS_RUNNING};
require CPAN;
delete $ENV{PERL5_CPANPLUS_IS_RUNNING} if $no_cpanplus_env;
delete $ENV{PERL5_CPAN_IS_RUNNING} if $no_cpan_env;

# and make sure that the user doesn't have any existing CPAN config that'll
# cause us problems for the next few steps.
{
    local $@;
    eval { require CPAN::HandleConfig; };
    # Need newish CPAN.pm for this, ergo skip it if that version of CPAN isn't
    # installed yet.
    # It will already be installed by the time we reach here if bootstrapping,
    # otherwise, if we're running from CPAN then it will be installed soon
    # enough, and we'll come back here..
    if (!$@ ) {
        CPAN::HandleConfig->require_myconfig_or_config;
        if ( $CPAN::Config ) {
            for my $eumm_setting ( qw/makepl_arg make_install_arg/ ) {
                if ($CPAN::Config->{$eumm_setting} =~ /(?:PREFIX|INSTALL_BASE)/) {
                    die <<"DEATH";
WHOA THERE! It looks like you've got $CPAN::Config->{$eumm_setting} set. This is
known to cause problems with local::lib. Please either remove this setting or
clear out your .cpan directory.
DEATH
                }
            }

            for my $mb_setting (qw/mbuild_arg mbuild_install_arg mbuildpl_arg/) {
                if ($CPAN::Config->{$mb_setting} =~ /(?:--prefix|--install_base)/) {
                    die <<"DEATH";
WHOA THERE! It looks like you've got $CPAN::Config->{$mb_setting} set. This is
known to cause problems with local::lib. Please either remove this setting or
clear out your .cpan directory.
DEATH
                }
            }
        }
    }
    else {
        my $error = $@;
        require CPAN;
        # Explode if it looks like requiring CPAN::HandleConfig should
        # have worked, but didn't.
        die($error) if $CPAN::VERSION >= $required_CPAN;
    }
}

if ($bootstrapping) {
  auto_install_now;
  postamble <<"END";
PERL     += $bootstrapping_args
FULLPERL += $bootstrapping_args
END
} else {
  auto_install;
}
chdir($cwd);
WriteAll;
