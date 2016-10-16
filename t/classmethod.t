use strict;
use warnings;
use Test::More tests => 7;
use lib 't/lib';
use TempDir;
use File::Spec::Functions qw(catdir);

use local::lib ();

my $c = 'local::lib';

{
    is $c->resolve_empty_path, '~/perl5',
      'empty path resolves to ~/perl5';
    is $c->resolve_empty_path('foo'), 'foo',
      'defined path resolves to same path';
}

{
    my $warn = '';
    local $SIG{__WARN__} = sub { $warn .= $_[0] };
    my $dir = mk_temp_dir;
    my $ll_dir = catdir($dir, 'splat');
    $c->ensure_dir_structure_for($ll_dir);
    ok -d $ll_dir, 'base dir created';
    ok -d $c->install_base_bin_path($ll_dir), 'bin dir created';
    ok -d $c->install_base_perl_path($ll_dir), 'lib dir created';
    ok -d $c->install_base_arch_path($ll_dir), 'arch dir created';
    like $warn, qr/^Attempting to create directory/,
      'warning about creation';
}
