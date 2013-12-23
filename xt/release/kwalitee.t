use strict;
use warnings;
use Test::More;

BEGIN {
  plan skip_all => 'release only test'
    unless -f 'META.yml';
}
use Test::Kwalitee;
