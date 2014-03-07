use strict;
use warnings;
use Test::More;
BEGIN {
  plan skip_all => 'Test::CPAN::Changes not available'
    if !eval { require Test::CPAN::Changes };
}

use Test::CPAN::Changes;
changes_file_ok('Changes');
