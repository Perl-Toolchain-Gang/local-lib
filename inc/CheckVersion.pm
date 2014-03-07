package inc::CheckVersion;
use strict;
use warnings;

sub import {
  my $target = caller;
  my $result = check_version(@ARGV);
  exit $result;
}

sub check_version {
  my ($module, $need_v) = @_;
  require ExtUtils::MakeMaker;
  (my $file = "$module.pm") =~ s{::}{/}g;
  my ($pm) = grep { -e } map { "$_/$file" } @INC;
  if (!$pm) {
    return 1;
  }
  my $v = MM->parse_version($pm) || 0;
  $v = eval $v;
  if ($v >= $need_v) {
    return 0;
  }
  return 2;
}

1;
