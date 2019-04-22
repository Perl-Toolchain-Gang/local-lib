use strict;
use warnings;

# something else (presumably a core module that local::lib uses) loads Carp,
# and then later on something loads Carp::Heavy from the local-lib, which is
# at a newer version

use Carp;
use Test::More tests => 6;
use File::Spec;
use File::Path qw(mkpath rmtree);   # use legacy versions for backcompat
use Cwd qw(realpath);
use local::lib ();

is $Carp::Heavy::VERSION, undef, 'Carp::Heavy is not yet loaded';

my $carp_file = File::Spec->rel2abs($INC{'Carp.pm'});

# we do not use File::Temp because it loads Carp::Heavy.
my $libdir = File::Spec->catdir(File::Spec->tmpdir, 'tmp-carp-newer-' . $$);
my $carpdir = File::Spec->catdir($libdir, 'lib', 'perl5', 'Carp');
mkpath($carpdir);

{
    my $heavy = File::Spec->catfile($carpdir, 'Heavy.pm');
    open my $fh, '>', $heavy or die "failed to open $heavy for writing: $!";
    binmode $fh;
    print $fh "package Carp::Heavy;\nour \$VERSION = '500.0';\n";
    close $fh;
}
{
    # another module, simply to ensure that we got the libdir path correct
    my $foo = File::Spec->catfile($carpdir, 'Foo.pm');
    open my $fh, '>', $foo or die "failed to open foo heavy for writing: $!";
    binmode $fh;
    print $fh "package Carp::Foo;\nour \$VERSION = '200.0';\n";
    close $fh;
}

local::lib->import('--no-create', $libdir);

require Carp::Foo;
is $Carp::Foo::VERSION, '200.0',
  'some other module was loaded from our local::lib';

my $expected_heavy = do {
  my ($v, $d) = File::Spec->splitpath($carp_file);
  $d = File::Spec->catdir(File::Spec->splitdir($d), 'Carp');
  realpath(File::Spec->catpath($v, $d, 'Heavy.pm'));
};

ok $INC{'Carp/Heavy.pm'}, 'Carp::Heavy has now been loaded';
is realpath($INC{'Carp/Heavy.pm'}), $expected_heavy,
  'Carp::Heavy loaded from correct location';

SKIP: {
    skip "Carp::Heavy does not have a version in Carp < 1.22", 1
        if $Carp::VERSION < '1.22'; # Carp::Heavy namespace did not exist

    is $Carp::Heavy::VERSION, $Carp::VERSION,
        'Carp::Heavy matching Carp was loaded'
        or do {
          diag "Carp was loaded from        $INC{'Carp.pm'}";
          diag "Carp::Heavy was loaded from $INC{'Carp/Heavy.pm'}";
        };
}

isnt $Carp::Heavy::VERSION, '500.0',
  'Carp::Heavy was not loaded from our local::lib';


END {
    rmtree($libdir) if $libdir;
}
