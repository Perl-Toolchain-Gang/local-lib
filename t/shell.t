use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Basename qw(dirname);
use File::Temp ();
use Config;
use local::lib ();

my @paths = File::Spec->path;
sub which {
  my $shell = shift;
  my ($full) =
    grep { -x }
    map { File::Spec->catfile( $_, $shell) }
    File::Spec->path;
  return $full;
}

my $extra_lib = '-I"' . dirname(dirname($INC{'local/lib.pm'})) . '"';

my @shells;
for my $shell (
  {
    name => 'sh',
  },
  {
    name => 'csh',
    opt => '-f',
  },
  {
    name => 'fish',
  },
  {
    name => 'cmd.exe',
    opt => '/Q /D /C',
    ext => 'bat',
    perl => qq{@"$^X"},
    skip => $^O eq 'cygwin',
  },
  {
    name => 'powershell.exe',
    opt => '-NoProfile -ExecutionPolicy Unrestricted -File',
    ext => 'ps1',
    perl => qq{& '$^X'},
    skip => $^O eq 'cygwin',
  },
) {
  my $name = $shell->{name};
  $shell->{shell} = which($name);
  $shell->{ext}   ||= $name;
  $shell->{perl}  ||= qq{"$^X"};
  if (@ARGV) {
    next
      if !grep {$_ eq $name} @ARGV;
    if (!$shell->{shell}) {
      warn "unable to find executable for $name";
      next;
    }
  }
  elsif ($shell->{skip} || !$shell->{shell}) {
    next;
  }
  push @shells, $shell;
}

if (!@shells) {
  plan skip_all => 'no supported shells found';
}
plan tests => 6*@shells;

my $sep = $Config{path_sep};

my $root = File::Spec->rootdir;
for my $shell (@shells) {
  my $ll = File::Temp->newdir();
  my $ll_dir = local::lib->normalize_path("$ll");
  local $ENV{PERL_LOCAL_LIB_ROOT};
  delete $ENV{PERL_LOCAL_LIB_ROOT};
  local $ENV{PATH} = $root;
  local $ENV{PERL5LIB};
  delete $ENV{PERL5LIB};
  my $bin_path = local::lib->install_base_bin_path($ll_dir);
  mkdir $bin_path;
  my $env = call_ll($shell, "$ll");
  is $env->{PERL_LOCAL_LIB_ROOT}, $ll_dir,
    "$shell->{name}: activate root";
  like $env->{PATH}, qr/^\Q$bin_path$sep$root\E(?:$|\Q$sep\E)/,
    "$shell->{name}: activate PATH";
  is $env->{PERL5LIB}, local::lib->install_base_perl_path($ll_dir),
    "$shell->{name}: activate PERL5LIB";

  $ENV{$_} = $env->{$_} for qw(PATH PERL5LIB PERL_LOCAL_LIB_ROOT);
  $env = call_ll($shell, '--deactivate', "$ll");

  is $env->{PERL_LOCAL_LIB_ROOT}, undef,
    "$shell->{name}: deactivate root";
  like $env->{PATH}, qr/^\Q$root\E(?:$|\Q$sep\E)/,
    "$shell->{name}: deactivate PATH";
  is $env->{PERL5LIB}, undef,
    "$shell->{name}: deactivate PERL5LIB";
}

sub call_ll {
  my ($info, @options) = @_;
  my $option = @options ? '='.join(',', @options) : '';

  local $ENV{SHELL} = $info->{shell};

  my $script
    = `"$^X" $extra_lib -Mlocal::lib$option` . "\n"
    . qq{$info->{perl} -Mt::lib::ENVDumper -e1\n};

  my $file = File::Temp->new(
    TEMPLATE => 'll-test-script-XXXXX',
    TMPDIR   => 1,
    SUFFIX   => '.'.$info->{ext},
  );
  print { $file } $script;
  close $file;

  my $opt = $info->{opt} ? "$info->{opt} " : '';
  my $cmd = qq{"$info->{shell}" $opt"$file"};
  my $out = `$cmd`;
  if ($?) {
    diag "script:\n$script";
    diag "running:\n$cmd";
    die "failed with code: $?";
  }
  my $VAR1;
  eval $out or die "bad output: $@";
  $VAR1;
}
