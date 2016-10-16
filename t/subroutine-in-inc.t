use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;

use lib 't/lib';
use TempDir;
use local::lib ();

my $dir = mk_temp_ll_dir;

my $base = scalar grep { ref eq 'CODE' } @INC;
my $sub = sub { () };
unshift @INC, $sub;
splice @INC, 3, 1, $sub;
push @INC, $sub;

local::lib->import($dir);

my $diff = (scalar grep { ref eq 'CODE' } @INC) - $base;
is $diff, 3, "found correct number of code refs in \@INC";
my $found = scalar grep { $_ eq $sub } @INC;
is $diff, 3, "found correct code refs in \@INC";
