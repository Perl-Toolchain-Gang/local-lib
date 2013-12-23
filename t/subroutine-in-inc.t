use strict;
use warnings FATAL => 'all';

use Test::More tests => 1;

use File::Spec;
use Cwd;
use lib 't/lib'; use TempDir;
use local::lib ();

sub CODE_in_INC() {
    return scalar grep { ref eq 'CODE' } @INC;
}

my $dir = mk_temp_dir('sub-in-INC-XXXXX');

my $base = CODE_in_INC;
unshift @INC, sub { () };
splice @INC, 3, 1, sub { () };
push @INC, sub { () };

local::lib->import($dir);

is( CODE_in_INC, $base + 3 );
