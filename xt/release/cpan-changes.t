use strict;
use warnings;
use Test::More $] < 5.010 ? ('skip_all' => 'need perl 5.10+') : (tests => 4);

use Test::CPAN::Changes;
changes_file_ok('Changes');
