package inc::ConfigCPAN;
use strict;
use warnings;

sub import {
  my $op = shift @ARGV
    or die "no operation specified!\n";
  my $do = __PACKAGE__->can("cmd_$op")
    or die "invalid operation $op\n";
  $do->(@ARGV);
  exit 0;
}

sub cmd_configure {
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
  }
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
