#!/usr/bin/env perl

use strict;
use warnings;
use IO::All;

my $mode;

my %tests;

my ($test, $segment, $text);

sub mode::outer {
  shift;
  my $line = $_[0];
  if ($line =~ /^=for test (\S+)(?:\s+(\S+))?/) {
    $mode = 'inner';
    ($test, $segment) = ($1, $2);
    $segment ||= '';
    $text = '';
  } elsif ($line =~ /^=begin testing/) {
    $mode = 'find_comment';
    ($test, $segment, $text) = ('', '', '');
  }
}

sub mode::find_comment {
  shift;
  my $line = $_[0];
  if ($line =~ /^\#\:\: test (\S+)(?:\s+(\S+))?/) {
    $mode = 'inner';
    ($test, $segment) = ($1, $2);
    $segment ||= '';
  }
}

sub mode::inner {
  shift;
  if ($_[0] =~ /^=/) {
    $mode = 'outer';
    push(@{$tests{$test}{$segment}||=[]}, $text);
  } else {
    $text .= $_[0];
  }
}


my @lines = io('lib/local/lib.pm')->getlines;

$mode = 'outer';

foreach my $line (@lines) {
  #warn "$mode: $line";
  mode->$mode($line);
}

foreach my $test (keys %tests) {
  my $data = $tests{$test};
  my $text = join("\n", q{
use strict;
use warnings;
use Test::More 'no_plan';
use local::lib ();
}, @{$data->{setup}||[]},
  map { "{\n$_}\n"; } @{$data->{''}||[]}
  );
  $text > io("t/${test}.t");
}
