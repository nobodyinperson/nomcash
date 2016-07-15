####################
### DataUtils.pm ###
####################

use strict;
use warnings;
use utf8; # Source code is utf8
binmode STDOUT, ":utf8"; # Terminal output is utf8
use List::Util;
use Scalar::Util;
use Data::Dumper;

package DataObjectReadOnly;
# Allgemeine Basisklasse für Datenobjekte
#
# KONTRUKTOR-ARGUMENTE:
# - Es wird ein einziges Argument übergeben: ein Hashref
# - Hashref hat folgende KEYS:
#
# - "Source" => 							Datenquelle (Skalar), default `pwd`
#
# - "KeyValueRegex" (optional) =>	mit qr// erstellter Regex, der im Listenkontext zwei Werte zurueckgibt: KEY und VALUE
#   											wenn nicht angegeben, defaultet es zu    qr/^([A-Za-z_0-9]+)(?:\s*|(?:\s+(.*)))$/  
#
# - "ModSubs" (optional) => 			Ref auf Liste mit Coderefs zum Verarbeiten von roh eingelesenen KEY-VALUE-Paaren
#   											( siehe hierfür Erklärung zu sub get_hash_from_file() )
#
# ATTRIBUTE:
# - Source			- Quelldatei/-Ordner zum Laden von Daten
# - ModSubs			- Arrayref mit Coderefs zum Verarbeiten von roh eingelesenen KEY-VALUE-Paaren
# - KeyValueRegex	- mit qr// ersteller Regex zum Verarbeiten von KEY-VALUE-Paaren
# - LoadedFiles	- Hash bereits geladener Dateien mit Pfaden
# - Data				- Geladene Daten
#
#
# CODEREFLISTE "ModSubs" zum Verarbeiten der Values
# - Wird ein KEY mit der Methode get_modified($key) angefordert, werden diese Subs der Reihe nach durchgegangen
# - Jeder Sub in dieser Liste wird KEY als erstes und VALUE als zweites Argument übergeben
# - Die Sub soll seine Eingabewerte auf Bedingungen überprüfen (z.B. besteht KEY nur aus Ziffern?)
# - Wenn die Bedingung passt, soll die Sub VALUE nehmen und wie gewünscht anpassen (z.B. splitten in eine Liste)
# - Es muss ein SKALARER Wert zurückgegeben werden! (ein String, oder eine Referenz auf eine Liste)
# - Der neue Wert für VALUE steht dann im zurückgegebenen HASH der sub get_hash_from_file() zur Verfügung
# - Sobald eine der Subs in der Liste nichts "undef"-mäßiges zurückgibt, wird der neue VALUE übernommen und keine weitere Sub mehr geprüft
 
# METHODEN:
# - get_hash_from_file($file)		- Dateiinhalt in einen Hash nach dem Muster "KeyValueRegex" laden und zurückgeben
# - load_hash_from_file($file)	- Dateiinhalt in das Attribut "Data" laden
# - load_next_file()					- Nächste Datei aus Source in das Attribut "Data" laden
# - load($key)							- So lange Dateien aus Source in "Data" laden, bis es $key gibt
# - get_raw($key)						- rohen, unverarbeiteten Value zu $key zurückgeben
# - get($key)							- mit ModSubs bearbeiteten VALUE zu $key zurückgeben
# - spit($key)							- Value zu $key printen

# Konstruktor
sub new {
	my $whichPkg = shift; # Packagename
	my $this = {}; # Leeren Objekt-Hash erzeugen

	# Argumente verarbeiten
	my $arg;	$arg = (ref($arg = shift) eq "HASH") ? $arg : {}; # Argument zu Hash verwursten
	$this->{Source}			= (exists $arg->{Source}) ? $arg->{Source} : $ENV{"HOME"}; # Datenquelle, default ist `pwd`
	$this->{ModSubs}			= (exists $arg->{ModSubs} and ref $arg->{ModSubs} eq "ARRAY") ? $arg->{ModSubs} : []; # ModSubs
	$this->{KeyValueRegex}	= (exists $arg->{KeyValueRegex} and ref $arg->{KeyValueRegex} eq "Regexp") ? $arg->{KeyValueRegex} : qr/^([A-Za-z_0-9]+)(?:\s*|(?:\s+(.*)))$/; # Regex für Key und Value

	$this->{LoadedFiles}	= {}; # Leeren Hash für geladene Dateien erstellen
	$this->{LoadedFiles}->{"*ANONYMOUS*"} = []; # Leere Liste für Datensätze, die nicht aus Dateien kommen
	$this->{Data}			= {}; # Leeren Datenhash erzeugen
	bless $this, $whichPkg; # Objekt-Hash der Klasse zuordnen
	return $this; # Objekt zurückgeben	
	}


# Laden eines Hashes {"KEY"} -> "VALUE" nach dem Muster von Regex aus einer Liste übergebener Zeilen
#
# Package-Subroutine, kann auch ohne Objekt aufgerufen werden
# Hashreferenz wird zurückgegeben
# Dies ist Grundlage für Subroutine get_hash_from_file()
#
# Eingelesen wird zeilenweise Struktur "KEY   VALUE" bzw.
# KEY
# ...VALUE...
# KEY
#
# ARGUMENTE
# - Ref auf Liste mit Zeilen
# - Regex (optional) der KEY und VALUE trennt
#   -> wird im Listenkontext auf jede Dateizeile angewandt
#   -> soll im Listenkontext zwei Werte zurück geben: KEY und VALUE 
#
sub get_hash_from_lines {
	my $REGEX = List::Util::first { ref eq "Regexp" } @_; # Suche den ersten RegEx, den Du finden kannst
	$REGEX = qr/^([A-Za-z_0-9]+)(?:\s+(.*))?$/ unless defined $REGEX; # Wenn keiner dabei war, nimm einen Standard-RegEx

   my @LINES = grep { ref eq '' } @_; # Zeilen sind alles, was keine Referenz zu irgendwas ist

	my $Hash = {}; # Hash-Vorlage
	my ($key, $value);
	NEXTKEYSEARCH: while(defined ($_ = shift @LINES)) { # Gehe alle Zeilen durch 
		next if m/^$/; # Leerzeilen auslassen
		($key, $value) = m/$REGEX/; # Suche in der aktuellen Zeile nach Key und Value
		next unless defined $key; # Wenn weder Kommentarzeile noch Mehrzeilenanfang, nächste Zeile
		goto SAVE if($key and $value); # Key-Value-Paar sichern
		# Nach Mehrzeilentext suchen
		$value = "" unless $value; # Wenn $value undef ist, leer belegen
		VALUEFILL: while(defined ($_ = shift @LINES)) { # Gehe weiter durch
			while(chomp){}; # Entferne alle Newlinezeichen am Ende dieser Zeile
			$value .= "$_\n" unless $_ eq $key; # Hänge die aktuelle Zeile mit einem NewLinezeichen an $value an
			if( $_ eq $key ) { chomp $value; last VALUEFILL} # Letzten Zeilenumbruch entfernen, weil unbenötigt und fertig nach dem aktuellen VALUE gesucht
			}
		SAVE: $Hash->{$key}=$value; # Im Hash ablegen
		}

	return $Hash; # Hash zurueckgeben
	}



# Laden einer einfachen Datei in einen Hash {"KEY"}->"Value"
#
# Gibt Hashref zurück
#
# Dies ist Grundlage für Subroutine load_hash_from_file()
#
# Datei hat zeilenweise Struktur "KEY   VALUE" bzw.
# KEY
# ...VALUE...
# KEY
#
# ARGUMENTE
# - Dateipfad
# - (optional) Regex für die Unterscheidung Key-Value (s.o.)
#
sub get_hash_from_file {
	my $REGEX = List::Util::first { ref eq "Regexp" } @_; # Suche den ersten RegEx, den Du finden kannst
	$REGEX = qr/^([A-Za-z_0-9]+)(?:\s+(.*))?$/ unless defined $REGEX; # Wenn keiner dabei war, nimm einen Standard-RegEx
	
	my $FILE = List::Util::first { -e -f -r } @_; # Die erste lesbare Datei, die Du in den Argumenten findest, wird genommen
	return {} unless defined $FILE; # If no readable file was given, return empty hash

	open FILE, "<", "$FILE" or return 0; # Datei öffnen
	binmode FILE, ":utf8"; # Lies in UTF8
	my @Lines = <FILE>; # Datei einlesen

	# Hash aus Zeilen machen
	my $Hash = &get_hash_from_lines($REGEX,@Lines);

	close FILE;
	return $Hash; # Hash zurückgeben
	}



# Laden in den Hash $this->{Data}->{KEY}->"Value" aus Zeilen
# Achtung: Bereits existierende KEYS werden NICHT überschrieben!
# Gelesen wird die Datei mit Subroutine get_hash_from_file()
# Zeilen haben Struktur "KEY   VALUE" bzw.
# KEY
# ...VALUE...
# KEY
#
# ARGUMENTE
# - Ref auf Array mit Zeilen
# - (optional) overwrite-tag (irgendwas wahres, um vorhandenes zu überschreiben)
#
sub load_hash_from_lines {
	my $this = shift; # $this ist Objekt
	my $lines = shift; # Argument ist Dateiname
	my $overwrite = shift; # Überschreiben?

	# Hash aus der Datei $file laden
	my $hash = $this->get_hash_from_lines($this->{KeyValueRegex},@$lines);
	return 0 unless $hash;

	# gelesenen Hash in {"Data"} übertragen
	# Achtung: Bereits existierende KEYS werden je nach $overwrite überschrieben
	map { $this->{Data}->{$_} = $hash->{$_} unless ( defined $this->{Data}->{$_} and not $overwrite) } keys %$hash;

	# Protokollieren, dass diese KEYS nicht aus einer Datei kommen
	push $this->{LoadedFiles}->{"*ANONYMOUS*"}, keys %$hash;

	return 1;
	}


# Laden einer einfachen Datei in $this->{Data}->{KEY}->"Value"
# Achtung: Bereits existierende KEYS werden NICHT überschrieben!
# Gelesen wird die Datei mit Subroutine get_hash_from_file()
# Datei hat zeilenweise Struktur "KEY   VALUE" bzw.
# KEY
# ...VALUE...
# KEY
#
# ARGUMENTE
# - Dateipfad
# - (optional) overwrite-tag (irgendwas Wahres, um vorhandenes zu überschreiben)
#
sub load_hash_from_file($) {
	my $this = shift; # $this ist Objekt
	my $file = shift; # Argument ist Dateiname
	my $overwrite = shift; # Überschreiben?

	# Hash aus der Datei $file laden
	my $hash = $this->get_hash_from_file($this->{KeyValueRegex},$file);
	return 0 unless $hash;

	# gelesenen Hash in {"Data"} übertragen
	# Achtung: Bereits existierende KEYS werden je nach $overwrite überschrieben
	map { $this->{Data}->{$_} = $hash->{$_} unless ( defined $this->{Data}->{$_} and not $overwrite) } keys %$hash;

	my ($filefolder,$filename) = $file =~ m|^(.+/)([^/]+)$|; # Dateipfad in Dateiname und Ordner aufteilen
	my @keys = keys %$hash; # KEY-Liste
	$this->{LoadedFiles}->{$filefolder . $filename} = \@keys; # Dateipfad mit geladenen KEYS eintragen
	return 1;
	}



# Methode zum laden der nächsten Datei aus Source
# keine Argumente
# return 1, wenn Datei geladen wurde
# return 0, wenn keine Datei mehr übrig ist
sub load_next_file {
	use Cwd;
	my $this = shift; # $this ist Objekt
	my @allfiles; my @files;

	my ($filefolder,$filename);
	
	# Fallunterscheidung, Source ist Datei oder Ordner
	# Source ist eine Datei
	if(-f -r -e $this->{Source}) { 
		# Sourcepfad in Ordnername und Dateiname zerlegen
		($filename)   = $this->{Source} =~ m|^([^/]+)$|; # Dateipfad in Dateiname und Ordner aufteilen
		($filefolder) = $this->{Source} =~ m|^(.*/)[^/]+$|; # Dateipfad in Dateiname und Ordner aufteilen
		$filefolder = getcwd unless defined $filefolder; # Use cwd if undefined
		$filefolder .= "/" unless $filefolder =~ m|/$|; # Einen Slash an den Ordnernamen anhängen, wenn noch nicht vorhanden
		push @allfiles, $filename; # Alle verfügbaren Dateien "sind" nur Source-File
		}
	# Source ist Ordner
	elsif (-d -r -e $this->{Source}) {
		$filefolder = $this->{Source}; # Ordner ist Source
		$filefolder .= "/" unless $filefolder =~ m|/$|; # Einen Slash an den Ordnernamen anhängen, wenn noch nicht vorhanden
		opendir my $dh, $this->{Source} or return 0; # Source öffnen
		@allfiles = sort readdir $dh; # alle Dateien in Source
		}
	# Source existiert nicht / ist nicht lesbar
	else {
		warn "$this: Loading of new files failed: $this->{'Source'} does not exist or is not readable.\n";
		return 0;
		}

	@files = grep { not m/^.[.]?$/ and not exists $this->{LoadedFiles}->{$filefolder . $_} } @allfiles; # alle Dateien, die noch übrig sind
	return 0 unless @files; # Keine Dateien mehr übrig
	$filename = shift @files; # Dateiname ist nächste Datei
	$this->load_hash_from_file($filefolder . $filename); 
	# Nächste Datei laden, Rückgabewert entsprechend load_hash_from_file()
	}



# load-Methode:
# Lädt so lange Dateien aus Source, bis KEY gefunden wurde
# Wenn KEY gefunden wurde, erfolgreich mit 1 beenden
# Wenn KEY nicht gefunden wurde, beende mit 0
sub load($) {
	my $this = shift; # $this ist Objekt
	my $key = shift; # Argument ist $key
   return 1 if defined $this->{Data}->{$key}; # Wenn KEY schon geladen ist, erfolgreich beenden

	unless($this->load_next_file) { # Nächste Datei laden
		# Wenn keine Datei mehr übrig, Fehler ausgeben und beenden
		#warn "Key \"$key\" not found in Source $this->{'Source'}"; 
		return 0;
		}

	$this->load($key); # Sonst nochmal probieren
	}


# load_all - Methode
# Lädt alle Dateien aus Source
sub load_everything {
	my $this = shift; # $this ist Objekt
	
	my $loaded = 0; # Zählvariable für geladene Dateien

	# Alle Dateien laden
	$loaded++ while($this->load_next_file);

	return $loaded; # Anzahl geladener Dateien zurückgeben
	}


# VALUE(s) zu KEY(s) zurückgeben
# zur Not so lange Dateien aus dem Standardordner laden, bis man ihn hat!
sub get_raw {
	my $this = shift; # $this ist Objekt
	my @return = (); # Zurückzugebende Liste	
	my $key;

	while ($key = shift) { # Alle Argumente durchgehen
		# Key zurückgeben, wenn er gefunden wurde
		if($this->load($key)) { push @return, $this->{Data}->{$key} }
		else { push @return, ""; } # Sonst leeren String zurückgeben
		}
	
	# Zurückgeben
	if		(scalar @return == 0) { return "" }
	elsif	(scalar @return == 1) { return shift @return }
	else { return @return }
	}


# mit ModSubs verarbeiteten VALUE zu KEY zurückgeben
# zur Not so lange Dateien aus dem Standardordner laden, bis man ihn hat!
# Information zu ModSubs: Siehe Konstruktor-Erklärung
sub get($) {
	my $this = shift; # $this ist Objekt
	my @return = (); # Zurückzugebende Liste
	my $key;

	while($key = shift) { # Alle Argumente durchgehen
		if($this->load($key)) { # KEY wurde gefunden
			# Eventuell VALUE noch verarbeiten
			if($this->{ModSubs} and ref $this->{ModSubs} eq "ARRAY") { # Wenn Subs angegeben wurden
				my $tmp;
				# So lange $subs durchgehen, bis einer nicht undef oder so zurückgibt
				foreach my $sub (@{$this->{ModSubs}}) {
					next unless ref $sub eq "CODE"; # Nächstes Element, wenn warum auch immer kein Code drin steht
					last if ($tmp = $sub->($key,$this->{Data}->{$key})) # Wenn eine Sub etwas Wahres zurückgibt, ist Schluss
					}
				if($tmp) { push @return, $tmp; next } # verarbeiteten VALUE zurückgeben
				}
			push @return, $this->{Data}->{$key}; # VALUE zurückgeben
			}
		else { push @return, ""; } # Sonst leeren String zurückgeben
		}

	# Zurückgeben
	if		(scalar @return == 0) { return "" }
	elsif	(scalar @return == 1) { return shift @return }
	else { return @return }
	}


# VALUE zu KEY printen
sub spit($) {
	my $this = shift; # $this ist Objekt
	my $key = shift or return 0; # Argument ist $key
	if($this->load($key)) { 
		# KEY ausgeben, wenn er gefunden wurde
		print $this->{Data}->{$key};
		}
	else { print ""; } # Sonst leeren String ausgeben
	}

# ENDE package DataObjectReadOnly



package DataObject;
# Allgemeine Basisklasse für Datenobjekte, die nicht nur lesen, sondern auch in Dateien schreiben können
#
# KONTRUKTOR-ARGUMENTE:
# - Es wird ein einziges Argument übergeben: ein Hashref
# - Hashref hat folgende KEYS:
#
# - "Source" => 							Datenquelle (Skalar)
#
# - "KeyFileSub" (empfohlen) =>		Sub, der KEY, get(KEY) und get_modified(KEY) übergeben wird und die einen Dateinamen zum speichern zurückgeben soll
#
# - "KeyValueRegex" (optional) =>	mit qr// erstellter Regex, der im Listenkontext zwei Werte zurueckgibt: KEY und VALUE
#   											wenn nicht angegeben, defaultet es zu    qr/^([A-Z_0-9]+)(?:\s*|\s+(.*))$/  
#
# - "ModSubs" (optional) => 			Ref auf Liste mit Coderefs zum Verarbeiten von roh eingelesenen KEY-VALUE-Paaren
#   											( siehe hierfür Erklärung zu sub get_hash_from_file() )
#
#
# ATTRIBUTE:
# - Source			- Quelldatei/-Ordner zum Laden von Daten
# - ModSubs			- Arrayref mit Coderefs zum Verarbeiten von roh eingelesenen KEY-VALUE-Paaren
# - KeyFileSub		- Sub, der KEY, get(KEY) und get_modified(KEY) übergeben wird und die einen Dateinamen zum speichern zurückgeben soll
# - Change			- Hash mit Informationen zu geänderten KEY-VALUE-Paaren
# - WriteOut		- Hash für noch zu schreibende Dateien
# - LoadedFiles	- Hash bereits geladener Dateien mit Pfaden
# - Data				- Geladene Daten
#
# CODEREFLISTE zum Verarbeiten der Values
# - zweiter Parameter ist optional die Coderefliste
# - Wird ein KEY mit der Methode get_modified($key) angefordert, werden diese Subs der Reihe nach durchgegangen
# - Jeder Sub in dieser Liste wird KEY als erstes und VALUE als zweites Argument übergeben
# - Die Sub soll seine Eingabewerte auf Bedingungen überprüfen (z.B. besteht KEY nur aus Ziffern?)
# - Wenn die Bedingung passt, soll die Sub VALUE nehmen und wie gewünscht anpassen (z.B. splitten in eine Liste)
# - Es muss ein SKALARER Wert zurückgegeben werden! (ein String, oder eine Referenz auf eine Liste)
# - Der neue Wert für VALUE steht dann im zurückgegebenen HASH der sub get_hash_from_file() zur Verfügung
# - Sobald eine der Subs in der Liste nichts "undef"-mäßiges zurückgibt, wird der neue VALUE übernommen und keine weitere Sub mehr geprüft
# 
# METHODEN:
# - get_hash_from_file($file)		- Dateiinhalt in einen Hash nach dem Muster "KeyValueRegex" laden und zurückgeben
# - load_hash_from_file($file)	- Dateiinhalt in das Attribut "Data" laden
# - load_next_file()					- Nächste Datei aus Source in das Attribut "Data" laden
# - load($key)							- So lange Dateien aus Source in "Data" laden, bis es $key gibt
# - get_raw($key)						- rohen, unverarbeiteten Value zu $key zurückgeben
# - get($key)							- mit ModSubs bearbeiteten VALUE zu $key zurückgeben
# - spit($key)							- Value zu $key printen
# - set($key,$newvalue)				- KEY mit VALUE belegen, Aktion in Change protokollieren
# - delete($key)						- VALUE von KEY leeren, im Change schreiben, dass KEY gelöscht werden soll
# - add($key,$number)				- $number auf VALUE von KEY addieren (+ Change aktialisieren)
# - increase($key)					- VALUE von KEY um 1 erhöhen (+ Change aktialisieren)
# - decrease($key)					- VALUE von KEY um 1 verringern (+ Change aktialisieren)
# - multiply($key,$number)			- VALUE von KEY mit $number multiplizieren (+ Change aktialisieren)
# - writeout()							- Speichere Änderungen

our @ISA = qw(DataObjectReadOnly); # Vererbung aller Methoden von DataObjectReadOnly

# Konstruktor-Erweiterung
# neu: Change-Attribut
# neu: WriteOutAttribut
# neu: KeyFileSub-Argument
# KeyFileSub-Argument: Ref auf Sub, der KEY und get(KEY) übergeben wird und die daraus einen Dateinamen zum Abspeichern returnen soll
sub new {
	my $whichPkg = shift; # $whichPkg ist Packagename
	
	# Argumente verarbeiten
	my $arg; $arg = (ref($arg = shift) eq "HASH") ? $arg : {}; # Argument zu Hash verwursten
	my $this = $whichPkg->SUPER::new($arg); # Konstruktor von DataObjectBasic ausführen

	$this->{KeyFileSub} = (exists $arg->{KeyFileSub} and ref $arg->{KeyFileSub} eq "CODE") ? $arg->{KeyFileSub} : sub { shift }; # Sub für KEY->File-Zusammenhang
	$this->{ValToKeySub} = (exists $arg->{ValToKeySub} and ref $arg->{ValToKeySub} eq "CODE") ? $arg->{ValToKeySub} : sub { use Time::HiRes qw/time/; return Time::HiRes::time }; # Sub für VALUE->KEY-Zusammenhang	
	$this->{Change} = {}; # Hash für geänderte KEY-VALUE-Paare
	$this->{WriteOut} = {}; # Hash für zu schreibende Dateien

	return $this;
	}


# Methode zum Ändern/Setzen des VALUES eine KEY-VALUE-Paares
# Sinn: In Change schreiben, was wie geändert wurde, damit im writeout nur die betroffenen Dateien beschrieben werden
# ARGUMENTE
#	- KEY
#	- NEUER VALUE (wenn undef, wird KEY gelöscht!)
sub set {
	my $this = shift; # $this ist Objekt
	my $key = shift; # Erstes Argument ist KEY
	my $newvalue = shift; # Zweites Argument ist neuer VALUE ( wenn undef, dann wird KEY gelöscht! )

	return 0 unless $key =~ $this->{KeyValueRegex}; # wenn kein korrekter KEY angegeben wurde

	my $loaded = $this->load($key); # Laden, also gucken, ob es KEY schon in Source gibt

	unless(defined $newvalue) { # KEY löschen, wenn neuer VALUE als undef angegeben war
		$this->{Change}->{$key} = "REMOVE";
		$this->{Data}->{$key} = "";
		return 1;
		}

	# VALUE zu KEY neu setzen und in Change Status setzen
	$this->{Change}->{$key} = ($loaded) ? "SET" : "NEW";
	$this->{Data}->{$key} = $newvalue;
	return 1;
	}


# Methode zum Erstellen eines Datensatzes
# Wenn ein Argument angegeben, dann erstelle einen Key aus $this->{ValToKeySub}
# Wenn zwei Argumente angegeben, dann setze mit set(KEY,VALUE);
sub newentry {
	my $this = shift; # $this ist Objekt
	my $value = pop; # Letztes Argument ist VALUE
	my $key = shift; # Übriges erstes Argument ist KEY
	
	if($key and $value) { # Beide definiert
		}
	elsif($value) { # Nur Value definiert
		my $sub = $this->{ValToKeySub};
		$key = &$sub($value); # Key aus Value erstellen
		}
	else { return 0; } # Dumm, nix definiert

	return $this->set($key,$value); # Einfach setzen
	}


# Methode zum Löschen eines Datensatzes "KEY"
# Grundlage ist set()-Methode
# ARGUMENT
# - KEY, der gelöscht werden soll
sub remove($) {
	my $this = shift; # $this ist Objekt
	my $key = shift; # Argument ist KEY
	$this->set($key, undef); # KEY mit set() löschen
	}


# Methode zum Addieren einer ZAHL auf den VALUE von KEY
# ARGUMENTE
# - KEY, auf dessen VALUE etwas addiert werden soll
# - ZAHL (default=1) Wert, der auf VALUE von KEY addiert werden soll
sub add {
	my $this = shift; # $this ist Objekt
	my $key = shift;  # Erstes Argument ist KEY
	my $number = shift;	# Zweites Argument ist ZAHL

	return 0 unless $key =~ $this->{KeyValueRegex}; # kein korrekter KEY angegeben
	$number = 1 unless Scalar::Util::looks_like_number($number); # Standardwert, wenn keine vernünftige ZAHL angegeben	

	my $tmp; # temporäre Variable
	unless($tmp = $this->get($key)) { # KEY laden, KEY noch nicht vorhanden
		$this->set($key, $number); # VALUE mit ZAHL besetzen
		}
	else { # KEY existiert
		if(Scalar::Util::looks_like_number($tmp)) { $this->set($key, $tmp + $number); } # VALUE war schon Zahl: Addieren!
		else { $this->set($key, $number); } # VALUE war keine Zahl: VALUE mit ZAHL besetzen
		}
	}


# Methode zum Erhöhen des VALUES von KEY um 1
# ARGUMENTE
# - KEY, dessen VALUE erhöht werden soll
sub increase {
	my $this = shift; # $this ist Objekt
	my $key = shift; # Argument ist KEY
	$this->add($key, 1); # VALUE zu KEY um 1 erhöhen
	}


# Methode zum Verringern des VALUES von KEY um 1
# ARGUMENTE
# - KEY, dessen VALUE verringert werden soll
sub decrease {
	my $this = shift; # $this ist Objekt
	my $key = shift; # Argument ist KEY
	$this->add($key, -1); # VALUE zu KEY um 1 verringern
	}


# Methode zum Multiplizieren des VALUES von KEY mit einer ZAHL
# ARGUMENTE
# - KEY, dessen VALUE mit etwas multipliziert werden soll
# - ZAHL (default = 2) Wert, mit dem VALUE von KEY multipliziert werden soll
sub multiply {
	my $this = shift; # $this ist Objekt
	my $key = shift;  # Erstes Argument ist KEY
	my $number = shift;	# Zweites Argument ist ZAHL

	return 0 unless $key =~ $this->{KeyValueRegex}; # kein korrekter KEY angegeben
	$number = 2 unless Scalar::Util::looks_like_number($number); # Standardwert, wenn keine vernünftige ZAHL angegeben	

	my $tmp; # temporäre Variable
	unless($tmp = $this->get($key)) { # KEY laden, KEY noch nicht vorhanden
		$this->set($key, $number); # VALUE mit ZAHL besetzen
		}
	else { # KEY existiert
		if(Scalar::Util::looks_like_number($tmp)) { $this->set($key, $tmp * $number); } # VALUE war schon Zahl: Addieren!
		else { $this->set($key, $number); } # VALUE war keine Zahl: VALUE mit ZAHL besetzen
		}
	}


# Anhand eines Hashes eine Datei beschreiben/ändern
# Hash sieht so aus:
# {
# "KEY1" => "new"
# "KEY2" => "set"
# "KEY3" => "remove"
# ...
# }
# Liest also evtl schon bestehende Datei ein, bearbeitet Inhalt je nach Hash und schreibt dann Datei wieder, wenn nötig
# 
# Argumete
# - Dateiname
# - Hashref mit Änderungen
#
# Gibt 1 zurück, wenn etwas geändert wurde, sonst 0
sub write_file {
	my $this = shift; # $this ist Objekt
	my $file = shift; # Erstes Argument ist Dateiname
	my $changehash = shift; # Zweites Argument ist Änderungshash
	return 0 unless ref $changehash eq "HASH";

   # Lies Hash aus Datei ein
	my $hash = $this->get_hash_from_file($file);
	#print "This was read into $this just before saving changes:",Data::Dumper::Dumper $hash;
	$hash = {} unless $hash; # Wenn Datei noch nicht existiert

	my $changed = 0; # Variable, ob etwas geändert wurde
	# Gehe alle KEYS aus dem Parameter-Hash durch
	foreach my $key (keys %$changehash) {
		#print $key;
		if(exists $hash->{$key}) { # KEY existiert schon in Datei
			if ($changehash->{$key} =~ m/remove/i) { # KEY soll gelöscht werden
				delete $hash->{$key};
				$changed = 1;
				#print "KEY $key existiert schon in Datei '$file', KEY soll gelöscht werden!\n";
				}
			elsif ($changehash->{$key} =~ m/(set)|(new)/i){ # KEY soll angepasst werden
				if($hash->{$key} ne $this->get_raw($key)) {
					#print "KEY $key existiert schon in Datei '$file', wurde von ".$hash->{$key}." zu ".$this->get_raw($key)." geändert, wird also geschrieben!\n";
					$hash->{$key}=$this->get_raw($key);
					$changed = 1;
					}
				else {
					#print "KEY $key existiert schon in Datei '$file', ist gleich wird also nicht überschrieben!\n";
					}
				}			
			}
		else { # KEY existiert noch nicht in der Datei
			if ($changehash->{$key} =~ m/remove/i) { # KEY soll gelöscht werden
				# nix tun, ist ja schon
				#print "KEY '$key' soll aus Datei '$file' gelöscht werden, KEY gibts dort aber gar nicht!\n";
				}
			elsif($changehash->{$key} =~ m/(set)|(new)/i) { # KEY soll angepasst werden
				$hash->{$key}=$this->get_raw($key);
				$changed = 1;
				#print "KEY '$key' soll in die DAtei '$file' geschrieben werden!\n";
				}			
			}
		}
	
	# Jetzt ist alter Inhalt der Datei geändert, muss aber noch gespeichert werden


	if($changed) { # Nur etwas ändern, wenns nötig ist
		# Hash zu Dateitext zusammenstückeln
		my @split; my $anz; my $lines = [];
		foreach my $key (sort keys %$hash) { # Alphabetisch KEYS durchgehen
			$anz = @split = split "\n", $hash->{$key};
			if($anz == 1 ) { # Nur einzeilig
				push $lines, $key . "\t" . $hash->{$key};
				}
			elsif($anz > 1) { # Mehrzeilentext
				push $lines, $key, @split, $key;
				}
			}
		# $lines sind zu schreibende Zeilen
	
		if(scalar @$lines == 0) { # Keine Zeilen zum Schreiben da
			unlink $file; # Datei ganz löschen
			#print "Datei $file wurde gelöscht, da kein Inhalt mehr rein soll!\n";
			}
		else { # Es sind Zeilen zum Schreiben da
			require File::Path; # Modul zum Erstellen von Directories einbinden
			# Alle erforderlichen Ordner zum Schreiben erstellen
			my $dir = $file; $dir =~ s|[^/]*$||; # Ordner herausfinden / Datei herausschneiden
			File::Path::make_path($dir); # Pfad erstellen
			# Datei zum Schreiben öffnen
			open FILE, ">", $file or return 0;
			binmode(FILE, ":utf8"); # In UTF-8 schreiben
			print FILE join("\n",@$lines); # Zeilen in die Datei schreiben
			close FILE;

			#print "Datei $file wurde mit KEYS ". join(", ", sort keys %$hash) ." geschrieben!\n";
			}
		}
	else { # Es gibt keine Änderungen!
		#print "An der Datei '$file' gibt es keine Änderungen, also wird sie nicht beschrieben!\n";
		}

	return $changed; # Zurückgeben, ob etwas geändert wurde oder nicht
	}


# Methode zum Füllen des Writeout-Hashes
sub set_writeout_hash {
	require List::Util; # List Utils einbinden
	my $this = shift; # $this ist Objekt

	# Alle von außen ohne File eingelesen KEYS in {"Change"} mit aufnehmen
	my $list = $this->{LoadedFiles}->{"*ANONYMOUS*"};
	map { $this->{Change}->{$_} = "NEW" } @$list;

	my $source; my $target;
	my $sub = $this->{KeyFileSub};
	#  Alle bearbeiteten KEYS durchgehen
	foreach my $key (keys $this->{Change}) {
		$source = List::Util::first { my $tmp = $_; List::Util::first { $key eq $_ } $this->{LoadedFiles}->{$_} } keys $this->{LoadedFiles}; # Quelle herausfinden
		$target = &$sub($source,$key,$this->get_raw($key),$this->get($key)); # Ziel ist Rückgabewert von KeyFilesub
		#print "$key: from $source to $target\n";
		$target = "homeless" unless $target; # Wenn Benutzer die KeyFileSub-Funktion schlecht definiert hat
		#print "$key: from $source to $target\n";

		# WriteOut-Hash füllen
		# Wenn Key von einer Datei in eine andere verschoben werden, in der alten löschen
		if($source) {
			$this->{WriteOut}->{$source}->{$key} = "REMOVE" if $source ne $target;
			}
		$this->{WriteOut}->{$target}->{$key}=$this->{Change}->{$key};
		}
	}


# Anliegende Änderungen abspeichern
# keine Argumente
# Erstellt zuerst einen Writeout-Hash der Form
# $this->{WriteOut} = {
# FILE1 => { KEY1 => "new", KEY2 => "remove", ...}
# FILE2 => { KEY3 => "set", KEY4 => "new", ...}
# FILE3 => { KEY5 => "new", KEY6 => "set", ...}
# }
# Ruft dann für jedes FILE die Funktion write_file() oben auf
sub writeout {
	my $this = shift; # $this ist Objekt
	my $changed = 0; # Zähler für geänderte Dateien

	# Produziere einen writeout-hash in $this->{WriteOut}
	$this->set_writeout_hash;

	# Jetzt alle Dateien, die geschrieben werden sollen, durchgehen
	foreach my $key (keys $this->{WriteOut}) {
		# Jede Datei mit write_file beschreiben
		$changed++ if $this->write_file($key,$this->{WriteOut}->{$key});
		}

	#print "$this: $changed Dateien geändert!\n";
	return $changed;
	}


# Die writeout-subroutine im DESTROY-Bereich hat extrem seltsame Probleme mit dem writeout
# verursacht. Auskommentiert geht es wieder. NICHT BENUTZEN!
sub DESTROY {
	my $this = shift; # $this ist Objekt
	#$this->writeout;
	}

# ENDE package DataObject

return 1;

