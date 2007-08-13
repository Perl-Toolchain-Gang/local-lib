use strict;
use warnings;
use inc::Module::Install;

name 'local-lib';
all_from 'lib/local/lib.pm';

requires 'ExtUtils::MakeMaker' => '6.31'; # version INSTALL_BASE was added
requires 'Module::Build' => '0.28'; # lib -> lib/perl5 change

WriteAll;
