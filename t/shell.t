use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Basename qw(dirname);
use File::Temp ();
use File::Path;
use Config;
use local::lib ();
use IPC::Open3 qw(open3);

my @ext = $^O eq 'MSWin32' ? (split /\Q$Config{path_sep}/, $ENV{PATHEXT}) : ();
sub which {
  my $shell = shift;
  my ($full) =
    grep { -x }
    map { my $x = $_; $x, map { $x . $_ } @ext }
    map { File::Spec->catfile( $_, $shell) }
    File::Spec->path;
  return $full;
}

BEGIN {
    *quote_literal =
      $^O ne 'MSWin32'
        ? sub { $_[0] }
        : sub {
          my ($text) = @_;
          $text =~ s{(\\*)(?="|\z)}{$1$1}g;
          $text =~ s{"}{\\"}g;
          $text = qq{"$text"};
          return $text;
        };
}

my %shell_path;
{
  my @shell_paths;
  if (open my $fh, '<', '/etc/shells') {
    my @lines = <$fh>;
    s/^\s+//, s/\s+$// for @lines;
    @shell_paths = grep { length && !/^#/ } @lines;
  }
  %shell_path =
    map { m{[\\/]([^\\/]+)$} ? ($1 => $_) : () }
    grep { defined && -x }
    ( '/bin/sh', '/bin/csh', $ENV{'ComSpec'}, @shell_paths );
}

my @extra_lib = ('-I' . dirname(dirname($INC{'local/lib.pm'})));
my $nul = File::Spec->devnull;

my @shells;
for my $shell (
  {
    name => 'sh',
    test => '-c "exit 0"',
  },
  {
    name => 'dash',
    test => '-c "exit 0"',
  },
  {
    name => 'bash',
    test => '-c "exit 0"',
  },
  {
    name => 'zsh',
    test => '-f -c "exit 0"',
  },
  {
    name => 'ksh',
    test => '-c "exit 0"',
  },
  {
    name => 'csh',
    test => '-c "exit 0"',
    opt => '-f',
  },
  {
    name => 'tcsh',
    test => '-c "exit 0"',
    opt => '-f',
  },
  {
    name => 'fish',
    test => '-c "exit 0"',
  },
  {
    name => 'cmd.exe',
    opt => '/Q /D /C',
    test => '/Q /D /C "exit 0"',
    ext => 'bat',
    perl => qq{@"$^X"},
    skip => $^O ne 'MSWin32',
  },
  {
    name => 'powershell.exe',
    shell => which('powershell.exe'),
    opt => '-NoProfile -ExecutionPolicy Unrestricted -File',
    test => '-NoProfile -Command "exit 0"',
    ext => 'ps1',
    perl => qq{& '$^X'},
    skip => $^O ne 'MSWin32',
  },
) {
  my $name = $shell->{name};
  $shell->{shell} ||= $shell_path{$name};
  $shell->{ext}   ||= $name;
  $shell->{perl}  ||= qq{"$^X"};
  if (@ARGV) {
    next
      if !grep {$_ eq $name} @ARGV;
    my $exec = $shell->{shell} ||= which($name);
    if (!$exec) {
      warn "unable to find executable for $name";
      next;
    }
  }
  elsif ($shell->{skip} || !$shell->{shell}) {
    next;
  }
  elsif ($shell->{test}) {
    no warnings 'exec';
    if (system "$shell->{shell} $shell->{test} > $nul 2> $nul") {
      diag "$name seems broken, skipping";
      next;
    }
  }
  push @shells, $shell;
}

if (!@shells) {
  plan skip_all => 'no supported shells found';
}
my @vars = qw(PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MM_OPT PERL_MB_OPT);
my @strings = (
  'string',
  'with space',
  'with"quote',
  "with'squote",
  'with\\bslash',
  'with%per%cent',
);

plan tests => @shells * (@vars * 2 + @strings * 2);

my $sep = $Config{path_sep};

my $root = File::Spec->rootdir;
for my $shell (@shells) {
  my $ll = local::lib->normalize_path(File::Temp::tempdir(CLEANUP => 1));
  local $ENV{$_}
    for @vars;
  delete $ENV{$_}
    for @vars;
  $ENV{PATH} = $root;
  my $orig = call_shell($shell, '');
  my $bin_path = local::lib->install_base_bin_path($ll);
  mkdir $bin_path;
  my $env = call_ll($shell, $ll);
  my %install_opts = local::lib->installer_options_for($ll);

  delete $orig->{$_} for qw(PERL_MM_OPT PERL_MB_OPT);
  my $want = {
    PERL_LOCAL_LIB_ROOT => $ll,
    PATH                => $bin_path,
    PERL5LIB            => local::lib->install_base_perl_path($ll),
    (map {; $_ => $install_opts{$_}} qw(PERL_MM_OPT PERL_MB_OPT)),
  };
  for my $var (keys %$want) {
    $want->{$var} = join($sep, $want->{$var}, $orig->{$var} || ()),
  }

  for my $var (@vars) {
    is $env->{$var}, $want->{$var},
      "$shell->{name}: activate $var";
  }

  $ENV{$_} = $env->{$_} for @vars;
  $env = call_ll($shell, '--deactivate', "$ll");

  for my $var (@vars) {
    is $env->{$var}, $orig->{$var},
      "$shell->{name}: deactivate $var";
  }

  my $shelltype = do {
    local $ENV{SHELL} = $shell->{shell};
    local::lib->guess_shelltype;
  };
  for my $string (@strings) {
    local $TODO = "$shell->{name}: can't quote strings with percents"
      if $shell->{name} eq 'cmd.exe' && $string =~ /%/;

    local $ENV{LL_TEST};
    delete $ENV{LL_TEST};
    my $script = local::lib->_build_env_string($shelltype, [
      LL_TEST => $string,
    ]);
    my $env = call_shell($shell, $script);
    is $env->{LL_TEST}, $string, "$shell->{name}: can quote [$string]";

    local $TODO = "$shell->{name}: can't test strings with double quotes"
      if $shell->{name} eq 'cmd.exe' && $string =~ /"/;

    $ENV{LL_TEST} = 'pre';
    $script = local::lib->_build_env_string($shelltype, [
      LL_TEST => [\"LL_TEST", $string],
    ]);
    $env = call_shell($shell, $script);
    is $env->{LL_TEST}, "pre$sep$string",
      "$shell->{name}: can append [$string]";
  }
}

sub call_ll {
  my ($info, @options) = @_;
  local $ENV{SHELL} = $info->{shell};

  open my $in, '<', File::Spec->devnull;
  open my $err, '>', File::Spec->devnull;
  open3 $in, my $out, $err,
    $^X, @extra_lib, '-Mlocal::lib', '-', '--no-create',
    map { quote_literal($_) } @options
    or die "blah";
  my $script = do { local $/; <$out> };
  close $out;
  call_shell($info, $script);
}

sub call_shell {
  my ($info, $script) = @_;
  $script .= "\n" . qq{$info->{perl} -Mt::lib::ENVDumper -e1\n};

  my ($fh, $file) = File::Temp::tempfile(
    'll-test-script-XXXXX',
    DIR      => File::Spec->tmpdir,
    SUFFIX   => '.'.$info->{ext},
    UNLINK   => 1,
  );
  print { $fh } $script;
  close $fh;

  my $opt = $info->{opt} ? "$info->{opt} " : '';
  my $cmd = qq{"$info->{shell}" $opt"$file"};
  my $output = `$cmd`;
  if ($?) {
    diag "script:\n$script";
    diag "running:\n$cmd";
    diag "failed with code: $?";
    return {};
  }
  my $env = eval $output or die "bad output: $@";
  $env;
}
