use strict;
use warnings;
use File::Spec;
use Cwd;
use vars qw($bootstrapping $bootstrapping_args $no_manpages);
use Config;

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

    system($^X, '-MExtUtils::MakeMaker 6.31', '-e1');
    my $eumm = $? >> 8;

    system($^X, '-MExtUtils::Install 1.43', '-e1');
    my $eui = $? >> 8;

    system($^X, '-MCPAN 1.80', '-e1');
    my $cpan = $? >> 8;
    my $cpan_command = '';

    system($^X, '-MCPAN', '-e',
      'my $done; require ExtUtils::MakeMaker;
       my $orig = ExtUtils::MakeMaker->can("prompt");
       *ExtUtils::MakeMaker::prompt = sub ($;$) {
         if (!$done && $_[0] =~ /manual configuration/) {
           $done++;
           return "no";
         }
         return $orig->(@_);
       };
       CPAN::Config->load;
       unless ($done || -w $CPAN::Config->{keep_source_where}) {
         my $save = $CPAN::Config->{urllist};
         delete @{$CPAN::Config}{keys %$CPAN::Config};
         $CPAN::Config->{urllist} = $save;
         CPAN::Config->init;
       }'
    );

    $ENV{PERL_MM_USE_DEFAULT} = 1;

    # XXX - remove the force on EUMM once its test suite survive PERL_MM_OPT

    if ($eumm) { # non-zero exit
      $cpan_command .= 'force("install","ExtUtils::MakeMaker"); ';
    }
    if ($eui) {
      $cpan_command .= 'install("ExtUtils::Install"); ';
    }
    if ($cpan) {
      $cpan_command .= 'force("install","CPAN"); ';
    }
    if(length $cpan_command) {
      system($^X, '-MCPAN', '-e', $cpan_command);
    }
    if ($cpan) {
      system($^X, '-MCPAN', '-e', 'CPAN::Config->load; CPAN::Config->commit;');
    }
    if($no_manpages) {
      # if we call this code directly, the changes get written to
      # $BOOTSTRAP/lib/perl5/CPAN/Config.pm, not where the user expects them to
      # be in their ~/.cpan/CPAN/MyConfig.pm.
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
requires 'ExtUtils::CBuilder'; # this and ParseXS are needed for MB C_support
requires 'ExtUtils::ParseXS';
requires 'Module::Build' => '0.28'; # lib -> lib/perl5 change
my $required_CPAN = '1.80';
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
    if (!$@) {
        CPAN::HandleConfig->load;
        for my $eumm_setting ( qw/makepl_arg make_install_arg/ ) {
            if ($CPAN::Config->{$eumm_setting} =~ /(?:PREFIX|INSTALL_BASE)/) {
                die "Possibly invalid config detected in $eumm_setting: " . $CPAN::Config->{$eumm_setting};
            }
        }

        for my $mb_setting (qw/mbuild_arg mbuild_install_arg mbuildpl_arg/) {
            if ($CPAN::Config->{$mb_setting} =~ /(?:--prefix|--install_base)/) {
                die "Possibly invalid config detected in $mb_setting: " . $CPAN::Config->{$mb_setting};
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
