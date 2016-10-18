use strict;
use warnings;

use Test::More 0.81_01;
use ExtUtils::MakeMaker;
use local::lib ();

my $ll_core;

BEGIN {
  $ll_core = local::lib->new->deactivate_all;
  my ($pm) = grep { -e } map { "$_/CPAN.pm" } @{ $ll_core->inc };
  plan skip_all => qq{CPAN.pm not available in core perl}
    unless $pm;
  my $vd = my $v = MM->parse_version($pm) || 0;
  $v =~ tr/_//d;
  plan skip_all => qq{CPAN.pm $vd doesn't have built in local::lib support}
    if $v < 1.9600;
  plan tests => 2;
}

use lib 't/lib', 'xt/lib';
use File::Spec;
use TempDir;
use POSIX ();
use Digest::SHA;
use Digest::MD5;
use Data::Dumper;
use dist_util;

my $local_cpan = mk_temp_dir('CPAN');
note "building fake cpan ($local_cpan)";
mkdir "$local_cpan/authors";
mkdir "$local_cpan/authors/id";
mkdir "$local_cpan/modules/";

my %modules;
make_dist "$local_cpan/authors/id/local-lib-bootstrap.tar.gz";
$modules{'local::lib'} = 'local-lib-bootstrap.tar.gz';

for my $module (qw(ExtUtils::MakeMaker ExtUtils::Install Module::Build CPAN)) {
  (my $dist_name = $module) =~ s{::}{-}g;
  (my $file_name = "$module.pm") =~ s{::}{/}g;
  my ($real_mod) = grep -e, map { "$_/$file_name" } @{$ll_core->inc};
  next
    unless $real_mod;
  my $dist = mk_temp_dir("$dist_name-fake");
  writefile "$dist/Makefile.PL", <<"END_MAKEFILEPL";
use strict;
use warnings;
BEGIN {
  die "PERL_MM_OPT not set to local::lib"
    unless \$ENV{PERL_MM_OPT} && \$ENV{LOCAL_LIB_CPAN_TEST}
      && \$ENV{PERL_MM_OPT} =~ /\\Q\$ENV{LOCAL_LIB_CPAN_TEST}/;
}

use ExtUtils::MakeMaker;
WriteMakefile(NAME => '$module');

END_MAKEFILEPL
  mkdir "$dist/lib";
  my $dir = "$dist/lib";
  my @parts = split /::/, $module;
  pop @parts;
  for my $part (@parts) {
    $dir .= "/$part";
    mkdir $dir;
  }
  writefile "$dist/lib/$file_name", <<"END_PM";
package $module;
\$VERSION = 9999;
require "$real_mod";
END_PM
  tar $dist, "$local_cpan/authors/id/$dist_name-fake.tar.gz";
  $modules{$module} = "$dist_name-fake.tar.gz";
}

my %checksums;
for my $file (values %modules) {
  my $full_file = "$local_cpan/authors/id/$file";
  $checksums{$file} = {
    'mtime'     => POSIX::strftime('%Y-%M-%D', gmtime),
    'size'      => -s $full_file,
    'md5'       => Digest::MD5->new->addfile(do {
      open my $fh, '<', $full_file or die "$!";
      $fh;
    })->hexdigest,
    'sha256'    => Digest::SHA->new(256)->addfile($full_file, 'b')->hexdigest,
  };
}

writefile "$local_cpan/authors/id/CHECKSUMS",
  Data::Dumper->new([\%checksums], ['cksum'])->Indent(1)->Sortkeys(1)->Dump;

writefile "$local_cpan/authors/01mailrc.txt.gz", <<'END_MAILRC';
alias LOCAL "Local <LOCAL>"
END_MAILRC

my $packages = join "\n", map "$_ 9999 $modules{$_}", sort keys %modules;

writefile "$local_cpan/modules/02packages.details.txt.gz", <<"END_PACKAGES";
File:         02packages.details.txt
URL:          http://www.perl.com/CPAN/modules/02packages.details.txt
Description:  Package names found in directory authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   local::lib test
Line-Count:   2
Last-Updated: Wed, 21 Oct 2015 22:41:02 GMT

$packages
END_PACKAGES

writefile "$local_cpan/modules/03modlist.data.gz", <<"END_MODLIST";
File:        03modlist.data
Description: Empty module list
Modcount:    0
Written-By:  PAUSE version 1.005
Date:        Thu, 03 Apr 2014 04:17:11 GMT

package CPAN::Modulelist;
sub data { {} }
1;
END_MODLIST

my $home = mk_temp_dir('HOME');
my $ll_root = File::Spec->catdir($home, 'perl5');

my $cpan_url = do {
  my ($vol, $path) = File::Spec->splitpath($local_cpan, 1);
  my @dirs = File::Spec->splitdir($path);
  shift @dirs;
  unshift @dirs, $vol
    if length $vol;
  join '/', "file://", @dirs;
};

my $out = do {
  my %env = $ll_core->build_environment_vars;
  $env{LOCAL_LIB_CPAN_TEST} = $ll_root;
  $env{HOME}                = $home;
  $env{HOMEDRIVE}           = undef;
  $env{HOMEPATH}            = undef;
  $env{USERPROFILE}         = undef;
  $env{PREFIX}              = undef;
  $env{INSTALL_BASE}        = undef;
  $env{MAKEFLAGS}           = undef;
  $env{PASTHRU}             = undef;
  $env{CPAN_MIRROR}         = $cpan_url;
  $env{PERL_MM_USE_DEFAULT} = 1;

  local @ENV{keys %env} = values %env;

  delete $ENV{$_}
    for grep { !defined $env{$_} } keys %env;

  note "running CPAN.pm bootstrap";
  cap_system local::lib::_perl, "xt/cpan-bootstrap.pl";
};

$out =~ /^#+\s*ENVIRONMENT\s*#+\s*\n(.*?)\n#+\s*END ENVIRONMENT\s*#+\s*\n/ms;
my %env = "$1" =~ /^(\w+)\s*(.*)$/mg;
$out =~ /^#+\s*INC\s*#+\s*\n(.*?)\n#+\s*END INC\s*#+\s*\n/ms;
my @inc = "$1" =~ /([^\r\n]+)/g;

my $failed;
ok -e "$ll_root/lib/perl5/local/lib.pm",
  'local::lib was installed'
  or $failed++;
like $inc[0], qr{^\Q$ll_root\E},
  'local::lib was activated'
  or $failed++;
diag $out
  if $failed;
