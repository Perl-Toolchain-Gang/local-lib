use strict;
use warnings;
use Test::More tests => 2;
use lib 't/lib';
use TempDir;
use Cwd;

my $dir = mk_temp_dir('test_local_lib-XXXXX');

use local::lib ();

my %inc;
my %perl5lib;

$inc{$_}--      for @INC;
$perl5lib{$_}-- for split /:/, $ENV{PERL5LIB};

local::lib->import($dir);
local::lib->import($dir);

$inc{$_}++      for @INC;
$perl5lib{$_}++ for split /:/, $ENV{PERL5LIB};

ok ! (grep { $inc{$_} > 1 } keys %inc), '@INC entries not duplicated';
ok ! (grep { $perl5lib{$_} > 1 } keys %perl5lib), 'ENV{PERL5LIB} entries not duplicated';
