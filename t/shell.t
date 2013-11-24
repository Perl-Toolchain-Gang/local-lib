use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp ();
use Config;
use local::lib ();

my @paths = File::Spec->path;
my @ext = $^O eq 'MSWin32'  ? (split /\Q$Config{path_sep}/, $ENV{PATHEXT}) : ('');
sub which {
  my $shell = shift;
  for my $dir (@paths) {
    my $file = File::Spec->catfile($dir||'.', $shell);
    for my $ext (@ext) {
      my $full = $file . $ext;
      return $full
        if -x $full;
    }
  }
  return;
}

my @extra_lib = do {
  my @paths = `$^X -le"print for \@INC"`;
  chomp @paths;
  my %paths;
  @paths{@paths} = ();
  grep { !exists $paths{$_} } @INC;
};

my $extra_lib = join ' ', map { qq{"-I$_"} } @extra_lib;

my @shells;
for my $shell (
  {
    name => 'sh',
  },
  {
    name => 'csh',
  },
  {
    name => 'cmd',
    opt => '/c',
    ext => 'bat',
    perl => qq{@"$^X"},
  },
  {
    name => 'powershell',
    opt => '-ExecutionPolicy Unrestricted',
    ext => 'ps1',
    perl => qq{& '$^X'},
  },
) {
  my $name = $shell->{name};
  next
    if @ARGV && !grep {$_ eq $name} @ARGV;
  $shell->{shell} = which($name) || next;
  $shell->{ext}   ||= $name;
  $shell->{perl}  ||= qq{"$^X"};
  push @shells, $shell;
}

if (!@shells) {
  plan skip_all => 'no supported shells found';
}
plan tests => 4*@shells;

my $sep = $Config{path_sep};

my $root = File::Spec->rootdir;
for my $shell (@shells) {
  my $ll = File::Temp->newdir();
  my $ll_dir = local::lib->normalize_path("$ll");
  local $ENV{PERL_LOCAL_LIB_ROOT};
  local $ENV{PATH} = $root;
  local $ENV{PERL5LIB} = $ENV{PERL5LIB};
  delete $ENV{PERL_LOCAL_LIB_ROOT};
  my $env = call_ll($shell, "$ll");
  is $env->{PERL_LOCAL_LIB_ROOT}, $ll_dir, "$shell->{name}: activate root";
  is $env->{PATH}, local::lib->install_base_bin_path($ll_dir)."$sep$root", "$shell->{name}: activate PATH";

  $ENV{$_} = $env->{$_} for qw(PATH PERL5LIB PERL_LOCAL_LIB_ROOT);
  $env = call_ll($shell, '--deactivate', "$ll");

  is $env->{PERL_LOCAL_LIB_ROOT}, undef, "$shell->{name}: deactivate root";
  is $env->{PATH}, $root, "$shell->{name}: deactivate PATH";
}

sub call_ll {
  my ($info, @options) = @_;
  my $option = @options ? '='.join(',', @options) : '';

  local $ENV{SHELL} = $info->{shell};

  my $file = File::Temp->new('ll-test-script-XXXXX',
    TMPDIR => 1,
    SUFFIX => '.'.$info->{ext},
  );

  $file->print(scalar `"$^X" $extra_lib -Mlocal::lib$option` . "\n");
  $file->print(qq{$info->{perl} -Mt::lib::ENVDumper -e1\n});
  $file->close;

  my $opt = $info->{opt} ? "$info->{opt} " : '';
  my $out = `"$info->{shell}" $opt"$file"`;
  if ($?) {
    die "failed with code: $?";
  }
  my $VAR1;
  eval $out or die "bad output: $@";
  $VAR1;
}
