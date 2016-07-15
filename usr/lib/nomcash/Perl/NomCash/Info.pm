#######################
### NomCash/Info.pm ###
#######################
# This is the Info module
package NomCash::Info;

use strict;
use warnings;
use utf8; # Source code is utf8
use POSIX qw/strftime/;

# Userdaten / Umgebungswerte herausfinden
our $USER			= $ENV{USER}; chomp($USER); # User herausfinden
our $HOMEDIR		= $ENV{HOME}; # Homedirectory herausfinden
our $TIME			= time; # Zeit zum Startpunkt
our $DATE			= strftime("%Y-%m-%d %H:%M:%S",localtime($TIME)); # Jetzige Zeit setzen
our $SANDBOX		= ""; # Dummy Sandbox, kann extern gesetzt werden

1;
