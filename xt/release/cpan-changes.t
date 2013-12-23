use strict;
use warnings;
use Test::More tests => 4;

use Test::CPAN::Changes;
changes_file_ok('Changes');
