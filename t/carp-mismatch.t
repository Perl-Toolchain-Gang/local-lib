use strict;
use warnings;

# something else (presumably a core module that local::lib uses) loads Carp,
# and then later on something loads Carp::Heavy from the local-lib, which is
# at a newer version

use Carp;
use Test::More tests => 4 + ( $Carp::VERSION < '1.22' ? 0 : 1 );
use File::Spec;
use File::Path qw(mkpath rmtree);   # use legacy versions for backcompat
use local::lib ();

is $Carp::Heavy::VERSION, undef, 'Carp::Heavy is not yet loaded';

# we do not use File::Temp because it loads Carp::Heavy.
my $libdir = File::Spec->catdir(File::Spec->tmpdir, 'tmp-carp-newer-' . $$);
my $carpdir = File::Spec->catdir($libdir, 'lib', 'perl5', 'Carp');
mkpath($carpdir);

{
    my $heavy = File::Spec->catfile($carpdir, 'Heavy.pm');
    open my $fh, '>', $heavy or die "failed to open $heavy for writing: $!";
    print $fh "package Carp::Heavy;\nour \$VERSION = '500.0';\n";
    close $fh;
}
{
    # another module, simply to ensure that we got the libdir path correct
    my $foo = File::Spec->catfile($carpdir, 'Foo.pm');
    open my $fh, '>', $foo or die "failed to open foo heavy for writing: $!";
    print $fh "package Carp::Foo;\nour \$VERSION = '200.0';\n";
    close $fh;
}

local::lib->import($libdir);

require Carp::Foo;
is $Carp::Foo::VERSION, '200.0',
  'some other module was loaded from our local::lib';

ok $INC{'Carp/Heavy.pm'}, 'Carp::Heavy has now been loaded';
is $Carp::Heavy::VERSION, $Carp::VERSION,
  'Carp::Heavy matching Carp was loaded'
    unless $Carp::VERSION < '1.22'; # Carp::Heavy namespace did not exist
isnt $Carp::Heavy::VERSION, '500.0',
  'Carp::Heavy was not loaded from our local::lib';


END {
    rmtree($libdir) if $libdir;
}
