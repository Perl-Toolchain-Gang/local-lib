use strict;
use warnings;
no warnings qw(redefine once);

my $url     = $ENV{CPAN_MIRROR};
my $ll_root = $ENV{LOCAL_LIB_CPAN_TEST};

require ExtUtils::MakeMaker;
{
  my $orig = \&ExtUtils::MakeMaker::prompt;
  *ExtUtils::MakeMaker::prompt = sub ($;$) {
    if ($_[0] =~ /manual configuration/) {
      return "no";
    }
    $orig->(@_);
  };
}

my %block_load = map { (my $f = "$_.pm") =~ s{::}{/}g; $f => 1 } qw(
  CPAN::Config
  File::HomeDir
);
unshift @INC, sub {
  die "Can't locate $_[1] in \@INC (\@INC contains: @INC).\n"
    if $block_load{$_[1]};
  ();
};

require CPAN;
my %config = %{ $CPAN::Config } = (
  urllist      => ["$url"],
  install_help => 'manual',
  check_sigs   => 0,
  shell        => (
    $^O eq 'MSWin32' ? ($ENV{COMSPEC} || 'cmd.exe')
                     : ($ENV{SHELL}   || '/bin/sh')
  ),
);

CPAN->import;
*CPAN::Distribution::check_integrity = sub { 1 };
*CPAN::HandleConfig::home = sub { $ENV{HOME} };
*CPAN::HandleConfig::cpan_config_dir_candidates = sub { "$ENV{HOME}/.cpan" };
*CPAN::HandleConfig::cpan_home_dir_candidates = sub { "$ENV{HOME}/.cpan" };
*CPAN::HandleConfig::cpan_data_home = sub { "$ENV{HOME}/.cpan" };
*CPAN::HandleConfig::cpan_home = sub { "$ENV{HOME}/.cpan" };
CPAN::Config->load;
%{ $CPAN::Config } = (
  %config,
  install_help => 'local::lib',
);
CPAN::Config->init;

require Data::Dumper;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Terse = 1;

print join "\n",
  '',
  '####### ENVIRONMENT ###########',
  (map {
    my $k = $_;
    my $v = $ENV{$_};
    $v = Data::Dumper::Dumper($v)
      if $v =~ /[^ -~]/;
    sprintf '%-20s %s', $k, $v;
  } sort keys %ENV),
  '####### END ENVIRONMENT #######',
  '####### INC ###################',
  @INC,
  '####### END INC ###############',
  '',
;
