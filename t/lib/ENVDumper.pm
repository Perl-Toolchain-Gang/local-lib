package t::lib::ENVDumper;
use Data::Dumper;

sub import {
  local $Data::Dumper::Terse = 1;
  print Dumper(\%ENV);
}

1;
