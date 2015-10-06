use strict;
use warnings;
use Test::More;
plan tests => 4;

use Test::CPAN::Changes;
changes_file_ok('Changes');
