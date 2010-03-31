use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd;

plan tests => 2;

my $dir = tempdir('test_local_lib-XXXXX', DIR => Cwd::abs_path('t'), CLEANUP => 1);

use local::lib ();
local::lib->import($dir);
local::lib->import($dir);

{
    my (%inc, %perl5lib);
    map { $inc{$_}++ } @INC;
    map { $perl5lib{$_} } split /:/, $ENV{PERL5LIB};
    ok ! grep({ $inc{$_} > 1 } keys %inc), '@INC entries not duplicated';
    ok ! grep({ $perl5lib{$_} > 1 } keys %perl5lib), 'ENV{PERL5LIB} entries not duplicated';
}
