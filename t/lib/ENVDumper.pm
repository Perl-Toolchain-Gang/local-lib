package ENVDumper;
use strict;
use warnings;
use Exporter;

our @EXPORT_OK = qw(dumpenv undump);

my %trans = (
  "\0" => "\\0",
  "\r" => "\\r",
  "\n" => "\\n",
  "\t" => "\\t",
  "\f" => "\\f",
  "\b" => "\\b",
  "\a" => "\\a",
  "\e" => "\\e",
  "\\" => "\\\\",
);

my %reverse = reverse %trans;

sub import {
  my ($class, @args) = @_;
  if (grep $_ eq '--dump', @args) {
    print dumpenv();
    exit 0;
  }
  goto &Exporter::import;
}

sub dumpenv {
  my $out = '';
  my ($match) = map qr/$_/, join ('|', map quotemeta, sort keys %trans);
  for my $key (sort keys %ENV) {
    my $value = $ENV{$key};
    $value = '' unless defined $value;
    s/($match)/$trans{$1}/g
      for ($key, $value);
    $out .= "$key\t$value\n";
  }
  $out;
}

sub undump {
  my $in = shift || '';
  my $out = {};
  my ($match) = map qr/$_/, join ('|', map quotemeta, sort keys %reverse);
  my @lines = split /\r\n?|\n/, $in;
  for my $line (@lines) {
    my ($key, $value) = split /\t/, $line, 2;
    $_ && s/($match)/$reverse{$1}/g
      for ($key, $value);
    $out->{$key} = $value;
  }
  $out;
}

1;
