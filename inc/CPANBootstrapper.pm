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

  if ($CPAN::VERSION < 1.94_54) {
    # CPAN can't download into a directory with spaces.  it shells out to
    # wget/curl, but doesn't quote the arguments.  Change directories beforehand
    # and use a relative filename so the command doesn't need quoting.
    require Cwd;
    require File::Basename;
    require File::Path;
    my $hosthard = defined &CPAN::FTP::hostdlhard ? 'hostdlhard' : 'hosthard';
    no strict 'refs';
    no warnings 'redefine';
    my $hosthardsub = \&{"CPAN::FTP::$hosthard"};
    *{"CPAN::FTP::$hosthard"} = sub {
      my($self,$host_seq,$file,$aslocal,@rest) = @_;
      if ($aslocal !~ m{[^a-zA-Z0-9+=_:,./-]}) {
        $hosthardsub->(@_);
      }
      my $cwd = Cwd::cwd();
      my $local_dir = File::Basename::dirname($aslocal);
      my $local_file = File::Basename::basename($aslocal);
      File::Path::mkpath($local_dir);
      my $out;
      eval {
        chdir $local_dir;
        $out = $hosthardsub->($self, $host_seq, $file, $local_file, @rest);
        1;
      } or do {
        chdir $cwd;
        die $@;
      };
      chdir $cwd;
      if (defined $out && $out eq $local_file) {
        return $aslocal;
      }
      return;
    };
  }

  if ($CPAN::VERSION < 1.87_51) {
    if (!$CPAN::META->has_inst("Compress::Zlib")) {
      # gzip and tar commands shell out without quoting arguments.  Wrap them in
      # a quoting routine.
      no warnings 'redefine';
      my $quote = sub {
        map +(
            /^"/                    ? $_
          : m{[^a-zA-Z0-9+=_:,./-]} ? qq["$_"]
                                    : $_
        ), @_;
      };

      my $gzip = \&CPAN::Tarzip::gzip;
      *CPAN::Tarzip::gzip = sub {
        $gzip->($_[0], $quote->(@_[1,2]));
      };
      my $gunzip = \&CPAN::Tarzip::gunzip;
      *CPAN::Tarzip::gunzip = sub {
        $gunzip->($_[0], $quote->(@_[1,2]));
      };
      my $gtest = \&CPAN::Tarzip::gtest;
      *CPAN::Tarzip::gtest = sub {
        $gtest->($_[0], $quote->($_[1]));
      };
      my $TIEHANDLE = \&CPAN::Tarzip::TIEHANDLE;
      *CPAN::Tarzip::TIEHANDLE = sub {
        $TIEHANDLE->($_[0], $quote->($_[1]));
      };
    }
    if (MM->maybe_command($CPAN::Config->{gzip})
        &&
        MM->maybe_command($CPAN::Config->{tar})) {
      my $untar = \&CPAN::Tarzip::untar;
      *CPAN::Tarzip::untar = sub {
        my ($class, $file) = @_;
        # the original untar checks for .gz at the end, so quote it like
        # "file.tar".gz
        my $gz = $file =~ s/\.gz$//;
        $file = qq["$file"] . ($gz ? '.gz' : '');
        $untar->($class, $file);
      };
    }
  }

  # ExtUtils::ParseXS is a prerequisite of Module::Build.  Previously,
  # it included a Build.PL file.  If CPAN.pm is configured to prefer
  # Module::Build (the default), it would see the Build.PL file and assume
  # MB was a prerequisite.  This introduces a circular dependency, which would
  # break installation.  None of Module::Build's prerequisites include a
  # Build.PL anymore, but continue to prefer EUMM as a precaution.
  $CPAN::Config->{prefer_installer} = "EUMM";

  if (defined &notest) {
    notest('install', @modules);
  }
  else {
    force('install', @modules);
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
    if (CPAN::HandleConfig->can('require_myconfig_or_config')) {
      CPAN::HandleConfig->require_myconfig_or_config;
    }
    else {
      local *CPAN::HandleConfig::missing_config_data = sub { () };
      CPAN::HandleConfig->load;
    }
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
