#######################
### NomCash/Base.pm ###
#######################

# NomCash-Basismodul
use strict;
use warnings;
use utf8; # Source code is utf8
use DataUtils;

package Stats;
# Klasse für Statistiken
our @ISA = qw(DataObject);
# ENDE package Stats


package Language;
# Klasse für Sprachen
our @ISA = qw(DataObjectReadOnly); # Language erbt von DataObject
# ENDE package Language


package StaticConfiguration;
# Klasse für statische Konfigurationen
our @ISA = qw(DataObjectReadOnly); # Ist ein nur-lesen DataObject
# ENDE package StaticConfiguration


package Configuration;
# Klasse für Konfigrationen
our @ISA = qw(DataObject); # Configuration erbt von DataObject
# ENDE package Configuration


package NomCashRDataBase;
use Data::Dumper;
# Klasse fuer eine Datenbank mit R-Interface

# Konstruktor
sub new {
	my $whichPkg = shift; # Packagename
	my $this = {}; # Leeren Objekt-Hash erzeugen

	$this->{StdDataVarname} = "NOCDATA"; # Standardvariable zum Speichern von Daten in R

	bless $this, $whichPkg; # Objekt-Hash der Klasse zuordnen

	# Argumente verarbeiten
	my $arg;	$arg = (ref($arg = shift) eq "HASH") ? $arg : {}; # Argument zu Hash verwursten
	
	require Statistics::R; # Load R-Interface
	$this->{R} = Statistics::R->new; # Create new R Interface

	# NomCash-Funktionen fuer R einlesen
	if( exists $arg->{FunctionSource} ) {
		# Wenn Datei, dann die eine Datei einlesen
		if( -f $arg->{FunctionSource} ) { $this->{R}->run_from_file($arg->{FunctionSource}) }
		elsif( -d $arg->{FunctionSource} ) { # Wenn Ordner, dann alle *.R-Dateien im Ordner einlesen
			unless(chdir($arg->{FunctionSource})) { # In die Source reingehen 
				bless $this, $whichPkg; # Wenns nicht klappt, nicht einlesen, sondern blessen
				return $this; # und returnen
				}
			foreach my $file ( glob '*.R' ) { $this->{R}->run_from_file($file) }; 
			}
		}
	else {
		die "The NomCashRDataBase constructor needs the attribute 'FunctionSource', which contains a file- or directoryname from where the basic functions are to be read! Stopped";
		}

	# Standard NomCash-Datendatei
	if( exists $arg->{DataSource} ) {
		system("touch $arg->{DataSource}") == 0 or die "Can't write to DataSource '$arg->{DataSource}'! Stopped"; # Test if DataSource is writeable
		$this->{DataSource} = $arg->{DataSource}; # Take DataSource-Parameter as serious
		# Read DataSource into R memory
		#$this->NOCreadappend( $this->{DataSource} ) # Vorerst nicht sofort einlesen, sondern im Hauptprogramm
		}
	else {
		die "The NomCashRDataBase constructor needs the attribute 'DataSource', which contains a filename from/to where the data is read/written! Stopped";
		}

	return $this; # Objekt zurückgeben	
	}


# Subroutine zum Einlesen einer *.noc-Datei (TABgetrennte CSV-Datei mit Header) in R
# Wrapper um die bereits im Kontruktor eingelesene R-Funktion "NOCreadinit"
# Diese Subroutine liest aus der Datei, die als Argument angegeben wird, in die R-Variable NOCDATA ein und registriert dies nicht als Datenbanksaenderung
#
# ARGUMENTE
#	- Dateiname zum Einlesen
#
sub NOCreadinit {
	my $this = shift; # $this ist Objekt
	my $infile; $infile = shift or $infile = $this->{DataSource}; # Argument ist Dateiname
	# Funktion NOCreadappend auf ausfuehren (Einlesen und an R-Variable NOCDATA anhaengen)
	$this->{R}->run(qq`NOCreadinit(infile="$infile")`);
	}



# Subroutine zum Einlesen einer *.noc-Datei (TABgetrennte CSV-Datei mit Header) in R
# Wrapper um die bereits im Kontruktor eingelesene R-Funktion "NOCreadappend"
# Diese Subroutine liest aus der Datei, die als Argument angegeben wird, in die R-Variable NOCDATA ein
#
# ARGUMENTE
#	- Dateiname zum Einlesen
#  - (optional) COLLAPSE: FALSE oder Spaltenname in Quotes(!), in der keine neuen Werte hinzugefuegt werden sollen
#
sub NOCreadappend {
	my $this = shift; # $this ist Objekt
	my $infile; $infile = shift or $infile = $this->{DataSource}; # Argument ist Dateiname
	my $collapse; $collapse = shift or $collapse = "FALSE"; # Zweites Argument ist evtl die COLLAPSE-Angabe
	# Funktion NOCreadappend auf ausfuehren (Einlesen und an R-Variable NOCDATA anhaengen)
	$this->{R}->run(qq`NOCreadappend(infile="$infile", collapse=$collapse)`);
	}


# Subroutine, um die übergebenen Datensätze in der R Datenbank auszuwählen
#
# ARGUMENTE
#  - Arrayref mit Zahlen(!), also Zeilennummern, die ausgewählt werden sollen
#
# Wrapper um die R-Funktion NOCselect()
sub NOCselect {
	my $this = shift; # $this ist Objekt
	my $selection = shift; # Argument ist Arrayref mit Zahlen	

	$this->{R}->set("NOCSELECTIONTEMP", $selection); # temporaere Spaltennamen belegen
	$this->{R}->run(qq`NOCselect(NOCSELECTIONTEMP)`);
	}

# Subroutine, um die ausgewählten Datensätze aus der R Datenbank 
# in einen Perl-Hash einzulesen
#
# ARGUMENTE
#  - keine
sub NOCgetselectedrows {
	require Encode; # Be able to decode things
	my $this = shift; # $this ist Objekt
	my $tmp; # Temporary variable
	# An annoying bug in the Statistics::R package has to be curved around here:
	# When you try to "get" something out of R that is a list of one or two elements inside R (like c(2) or c(3,4) for example), 
	# it is imported into perl as bogus. One element will just be a string, this may not be a bug, but is still annoying in this context.
	# The bug is with the two-element-list. Here, the Perl-R-Interface concatenates both elements and returns it as one string,
	# which is definitely not what you want. So a little workaround has to be done here.
	# First, to avoid the R session from dying by an error, check whether there is any header. If yes, return the transpose of the list.
	# Read into perl, this gives a header element of the transpose matrix and the desired elements. Inside perl, you can get rid of the leading header element.
	# UPDATE: The bug is EVEN more annoying!
	# Obviously, the kind of returned list is dependent on the terminal width (!) of the perl-r-interface.
	# Now, I just weed out everything that looks like [1,] header elements... works fine for now!

	# Get the actual selection
	$tmp = $this->{R}->get(qq`if( length(NOCgetselection())>0 ) { t(NOCgetselection()) } else { c() }`);
	shift $tmp if ref $tmp eq "ARRAY"; # Get rid of leading transpose header element
	my $selection= ref $tmp eq "ARRAY" ? $tmp : []; # make sure, it is an array ref
	$selection = [ grep { $_ !~ m/^\[[0-9,]+\]$/ } @$selection ]; # Weed out rubbish header elements

	# Get the header
	$tmp = $this->{R}->get(qq`if( length(NOCgetdatacolnames())>0 ) { t(NOCgetdatacolnames()) } else { c() }`);
	shift $tmp if ref $tmp eq "ARRAY"; # Get rid of leading transpose header element
	my $header = ref $tmp eq "ARRAY" ? $tmp : []; # make sure, $header is an array ref
	$header = [ grep { $_ !~ m/\[[0-9,]+\]/ } @$header ]; # Weed out rubbish header elements

	# TODO: Some problems when deleting not the last line
	# I think this sub is the problem

	# Get the data
	$tmp = $this->{R}->get(qq`NOCgetselectedrowsasvector()`);
	my @rows = ref $tmp eq 'ARRAY' ? @$tmp : ();


	my @list = (); # List for all hashes
	my $hash = {}; # Empty hash for data
	my $aktentry; # Actual entry
	while(@rows) { # As long as there is data left
		$hash = {};
		foreach my $headertmp (@{$header}) { # Iterate over the header
			$aktentry = shift @rows; 
			# Adjust content for good displaying
			$aktentry =~ s/^\s*(.*)\s*$/$1/g; # Remove whitespaces from beginning and end, mostly originating from the way R-->Perl
			$aktentry =~ s/(\\)?\\n/\n/g; # Replace newlines, R-internally as \\n
			$aktentry =~ s/<br>/\n/g; # Replace newlines, self-defined as <newline>
			$aktentry =~ s/<tab>/\t/g; # Replace newlines, self-defined as <newline>
			$aktentry =~ s/^<?NA>?$//g; # Empty fields that are NAs
			# Decode to perls internal representation
			$hash->{$headertmp} = Encode::decode("utf8",$aktentry); # Add to hash
			}
		push @list, $hash; # Concatenate the actual hash to the list
		}

	return @list; # Return the list
	}

# Subroutine zum Einfuegen eines neuen Datensatzes in die R-Datenbank
# Wrapper um die R-Funktion NOCsaveentryfromtemp und die Variablen NOCsaveentryCOLTEMP und NOCsaveentryVALTEMP
# ARGUMENTE
# 		- Hash { 'ENTRYTIME' => 12324123, 'AMOUNT' => 300, ... }
# !!! Keine Newline characters \n in den Einträgen, verträgt R nicht gut !!!
sub NOCsaveentries {
	my $this = shift; # $this ist Objekt
	my $data; 
 
	# Read as many arguments as are there
	while ( $data = shift ) { # the argument is the data
		next unless ref $data eq 'HASH'; # Stop if its not a hash
	
		# Get keys and values of the data
		my $colnames = [keys $data]; # These are the Column names
		my @replaced = map { s/\t/<tab>/g;$_ } map { s/\n/<br>/g;$_ } values $data; # Make replacements
		my $values   = \@replaced; # These are the values
		#print Dumper $colnames,$values;

		# R-interne temporaere Variablen belegen
		$this->{R}->set("NOCSAVEENTRYCOLTEMP", $colnames); # temporaere Spaltennamen belegen
		$this->{R}->set("NOCSAVEENTRYVALTEMP", $values); # temporaere Eintraege belegen
		
		# Funktion NOCsaveentryfromtemp() ausfuehren
		$this->{R}->run(qq`NOCsaveentryfromtemp()`);
		}
	}


# Subroutine zum Löschen von Datensätzen aus der R-Datenbank
# Sucht aus Argumenten die IDs heraus und übergibt an die R-Funktion NOCdeletebyIDs()
#
# ARGUMENTE
#	- Liste aus Datahashes
#
sub NOCdelete {
	my $this = shift; # $this ist Objekt
	my @HASHES = grep { ref eq 'HASH' } @_; # Get all given hashes
	my @IDs = map { $_->{ID} if exists $_->{ID} } @HASHES; # get IDs
	@IDs = grep { Scalar::Util::looks_like_number($_) } @IDs; # Get only numerics
	# Call Delete routine in R
	foreach (@IDs) {
		#print "NOCdelete is now running NOCdeletebyIDs($_)\n";
		$this->{R}->run(qq`NOCdeletebyIDs($_)`) ;
		}
	}

# Subroutine zum Speichern
# Speichert die aktuelle R-Variable NOCDATA in die DataSource-Datei
# Wrapper um die R-Funktion NOCwriteout
# 
# ARGUMENTE
#	- Name der R-Variable, der gespeichert werden soll (sonst Standardvariable)
#	- Dateiname, in die gespeichert werden soll (sonst Quelldatei)
#
sub NOCwriteout {
	my $this = shift; # $this ist Objekt
	#print "WRITEOUT!";
	#my $varname; $varname = shift or $varname = $this->{StdDataVarname}; # Erstes Argument Variablenname, sonst Standardname
	my $outfile; $outfile = shift or $outfile = $this->{DataSource}; # Zweites Argument Dateiname, sonst Quelldatei
	# Quotes hinzufuegen, wenn nicht vorhanden
	$outfile =~ s/(.*)/"$1"/ unless $outfile =~ m/^".*"$/;
	$this->{R}->run(qq`NOCDATAwriteout(outfile=$outfile)`); # NOCwriteout-Funktion ausfuehren
	}


# DESTROY-Subroutine
# Verhalten beim DESTROYen
# Evtl immer speichern, wenn Programm beendet wird? ...
sub DESTROY {
	my $this = shift;	
	# Vorerst nicht automatisch speichern
	#$this->NOCwriteout; # Writeout mit Standardwerten
	}

1;
