use strict;
use warnings;
use vars qw($bootstrapping);

BEGIN {
  if (grep { /^--bootstrap(?:=(.*))?$/ } @ARGV) {
    $bootstrapping = 1;
    my @args = (defined $1 ? ($1) : ());

    {
      local @INC = @INC;
      unshift(@INC, 'lib');
      require local::lib;
    }

    local::lib->import(@args);

    push(@ARGV,$ENV{PERL_MM_OPT});

    system($^X, '-MExtUtils::MakeMaker 6.31', '-e1');
    my $eumm = $? >> 8;

    system($^X, '-MCPAN 1.80', '-e1');
    my $cpan = $? >> 8;
    my $cpan_command = '';

    # XXX - remove the force on EUMM once its test suite survive PERL_MM_OPT

    if ($eumm) { # non-zero exit
      $cpan_command .= 'force("install","ExtUtils::MakeMaker"); ';
    }
    if ($cpan) {
      $cpan_command .= 'install("CPAN"); ';
    }
    if(length $cpan_command) {
      system($^X, '-MCPAN', '-e', $cpan_command);
    }

  }
}

use inc::Module::Install;

name 'local-lib';
all_from 'lib/local/lib.pm';

requires 'ExtUtils::MakeMaker' => '6.31'; # version INSTALL_BASE was added
requires 'ExtUtils::CBuilder'; # this and ParseXS are needed for MB C_support
requires 'ExtUtils::ParseXS';
requires 'Module::Build' => '0.28'; # lib -> lib/perl5 change
requires 'CPAN' => '1.80'; # sudo support

if ($bootstrapping) {
  auto_install_now;
} else {
  auto_install;
}

WriteAll;
