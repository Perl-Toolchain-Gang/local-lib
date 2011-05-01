#!/usr/bin/perl -w

use Test::More;

plan qw/no_plan/;

use File::Spec;
use Cwd;
use File::Temp qw/ tempdir /;
my $base;

sub CODE_in_INC() {
    return scalar grep { ref eq 'CODE' } @INC;
}

my $dir;

BEGIN {
    $base = CODE_in_INC;
    unshift @INC, sub { };
    splice @INC, 3, 1, sub { };
    push @INC, sub { };

    $dir = tempdir( DIR => Cwd::abs_path('t'), CLEANUP => 1 );
}

use local::lib( $dir );

is( CODE_in_INC, $base + 3 );
