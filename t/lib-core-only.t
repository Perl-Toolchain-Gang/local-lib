use strict;
use warnings FATAL => 'all';
use Test::More tests => 1;
use lib::core::only ();
use Config;

is_deeply(
  [ do { local @INC = @INC; lib::core::only->import; @INC } ],
  [ $Config{privlibexp}, $Config{archlibexp} ],
  'lib::core::only mangles @INC correctly'
);
