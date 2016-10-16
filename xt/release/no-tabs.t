use strict;
use warnings;
use Test::More ($ENV{RELEASE_TESTING} ? () : (skip_all => 'release testing only'));

use Test::NoTabs;
all_perl_files_ok('.');
