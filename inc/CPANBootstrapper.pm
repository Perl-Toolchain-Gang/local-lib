package CPANBootstrapper;
use strict;
use warnings;

sub import {
  my ($class, $op) = @_;

  die "no operation specified!\n"
    unless $op;
  my $do = $class->can("cmd_$op")
    or die "invalid operation $op\n";
  $do->(@ARGV);
  exit 0;
}

sub cmd_init_config {
  require ExtUtils::MakeMaker;
  my $done;
  my $orig = ExtUtils::MakeMaker->can("prompt");
  no warnings 'once', 'redefine';
  *ExtUtils::MakeMaker::prompt = sub ($;$) {
    if (!$done && $_[0] =~ /manual configuration/) {
      $done++;
      return "no";
    }
    return $orig->(@_);
  };
  require CPAN;
  CPAN->import;
  $CPAN::Config->{urllist} = ["http://www.cpan.org/"];

  CPAN::Config->load;
  unless ($done || -w $CPAN::Config->{keep_source_where}) {
    my $save = $CPAN::Config->{urllist};
    delete @{$CPAN::Config}{keys %$CPAN::Config};
    $CPAN::Config->{urllist} = $save;
    CPAN::Config->init;
  }
}

sub cmd_install {
  my @modules = @_;
  package main;
  require CPAN;
  CPAN->import;
  CPAN::Config->load;

  # ExtUtils::ParseXS is a prerequisite of Module::Build.  Previously,
  # it included a Build.PL file.  If CPAN.pm is configured to prefer
  # Module::Build (the default), it would see the Build.PL file and assume
  # MB was a prerequisite.  This introduces a circular dependency, which would
  # break installation.  None of Module::Build's prerequisites include a
  # Build.PL anymore, but continue to prefer EUMM as a precaution.
  $CPAN::Config->{prefer_installer} = "EUMM";

  force('install', @modules);
}

sub cmd_disable_manpages {
  require CPAN;
  CPAN->import;
  CPAN::HandleConfig->load;
  $CPAN::Config->{makepl_arg} = 'INSTALLMAN1DIR=none INSTALLMAN3DIR=none';
  $CPAN::Config->{buildpl_arg} = '--install_path libdoc="" --install_path bindoc=""';
  CPAN::Config->commit;
}

# make sure that the user doesn't have any existing CPAN config that'll
# cause us problems for the next few steps.
sub cmd_check {
  my $cpan_version = shift;
  # if CPAN loads this, it calls into CPAN::Shell which tries to run
  # autoconfiguration.  if it doesn't exist, we don't care
  eval { require File::HomeDir; };
  require CPAN;

  # Need newish CPAN.pm for this, ergo skip it if that version of CPAN isn't
  # installed yet.
  # It will already be installed by the time we reach here if bootstrapping,
  # otherwise, if we're running from CPAN then it will be installed soon
  # enough, and we'll come back here..
  if (eval { require CPAN::HandleConfig; } ) {
    CPAN::HandleConfig->require_myconfig_or_config;
    if ( $CPAN::Config ) {
      for my $setting (qw(
        makepl_arg make_install_arg
        mbuild_arg mbuild_install_arg mbuildpl_arg
      )) {
        my $value = $CPAN::Config->{$setting} or next;
        if ($setting =~ /^make/
          ? $value =~ /(?:PREFIX|INSTALL_BASE)/
          : $value =~ /(?:--prefix|--install_base)/
        ) {
          die <<"DEATH";
WHOA THERE! It looks like you've got $CPAN::Config->{$setting} set in
your CPAN config. This is known to cause problems with local::lib. Please
either remove this setting or clear out your .cpan directory.
DEATH
        }
      }
    }
  }
  else {
    # Explode if it looks like requiring CPAN::HandleConfig should
    # have worked, but didn't.
    die $@
      if $CPAN::VERSION >= $cpan_version;
  }
}

1;
