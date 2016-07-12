#######################
### NomCash/Gtk2.pm ###
#######################
# This is the Gtk2 Interface to NomCash
package NomCash::Gtk2;

use strict;
use warnings;
use utf8; # Diese Datei ist in utf8 codiert
use NomCash::Base; # Basismodul Nomcash einbinden
use NomCash::Info; # Informationsmodul einbinden
use Gtk2; # GTK2 benutzen
use Gtk2::Gdk::Keysyms; # Know the Keycodes
use Glib qw/TRUE FALSE/; # True und False Konstanten
use Data::Dumper; # Zum Dumpen von Variablen
binmode STDOUT, ":utf8"; # Terminaloutput ist utf8

# Package globals to be available in all subroutines
our ($LANG, $CONF, $PCNF, $DATA, $STAT, %GTK);

sub Nomcash_Gtk2_Configuration_init {
	######################################
	### Sprache herausfinden und laden ###
	######################################
		my $USERLANG	= Gtk2->get_default_language->to_string; # Sprache des Benutzers herausfinden
		$USERLANG 		=~ s/(^[a-z]{2})\W+.*/$1/i; # Unnoetigkeiten abschneiden
	
		# Allgemeiner Ordner fuer Sprachdateien
		my $LANGFOLDER = "$NomCash::Info::SANDBOX/usr/share/nomcash/lang/";
		my @LANGUAGES	= glob "$LANGFOLDER/*"; # Alle verfuegbaren Sprachen
		map { s|.*/([^/]+)$|$1|g } @LANGUAGES; # Nur Dateinamen wollen wir haben
		
		# Die zu benutzende Sprache ist die Usersprache.
		# Wenns die nicht gibt, nimm die erste Sprache, die Du findest!
		my $CURLANG = (grep {$_ eq $USERLANG} @LANGUAGES) ? $USERLANG : $LANGUAGES[0];
		# Konfiguration fuer Language
		my %langarg = (
		"Source" => "$LANGFOLDER/$CURLANG/gtk",
		"ModSubs" => [
			sub{my($key,$value)=@_; if( $key=~m/_KEYWD$/)	{my @tmp=split /\s+/,$value;return \@tmp } 	;return undef},
			sub{my($key,$value)=@_; if( $key=~m/_HASH$/)	{my %tmp=split /\t+|\n+/,$value;return \%tmp } 	;return undef}],
		);
		
		# Sprache laden
		$LANG = new Language \%langarg;
	
	
	#######################
	### Statistik laden ###
	#######################
	# Konfiguration fuer Statistik
		my %statarg = (
		"Source" => "$NomCash::Info::SANDBOX$NomCash::Info::HOMEDIR/.nomcash/stats/",
		"KeyFileSub" => 
		sub { # KeyFileSub definieren
			my($source,$key,$raw,$modified) = @_; # Argumente einlesen
			return "$NomCash::Info::SANDBOX$NomCash::Info::HOMEDIR/.nomcash/stats/gtk.stat" unless $source; # Wenn neuer Key, dann in Standardordner 
			return $source; # Sonst wieder zurueck in die gleiche Datei
			},
		);
		
		# Statistik laden
		$STAT = new Stats \%statarg;
		
	
	###########################
	### Konfiguration laden ###
	###########################
	# Konfiguration fuer allgemeine Konfiguration :-)
		my %confarg = (
		"Source" => "$NomCash::Info::SANDBOX/usr/share/nomcash/conf/gtk",
		"ModSubs" => [
			sub{my($key,$value)=@_; if( $key=~m/_LIST$/){my @tmp=split /\s+/,$value;return \@tmp } ;return undef},
			sub{my($key,$value)=@_; if( $key=~m/_HASH$/)	{my %tmp=split /\t+|\n+/,$value;return \%tmp } 	;return undef},
			sub{my($key,$value)=@_; if( $key=~m/_HASHOFLISTS$/){my %tmp=split /\t+|\n+/,$value;%tmp=map {($_,[split /,/,$tmp{$_}])} keys %tmp;return \%tmp } ;return undef},
			],
		);
		
		# Konfiguration laden
		$CONF = new StaticConfiguration \%confarg;
	
	
	#######################################
	### Persönliche Konfiguration laden ###
	#######################################
	# Konfiguration fuer persönliche Konfiguration 
		my %pcnfarg = (
		"Source" => "$NomCash::Info::SANDBOX$NomCash::Info::HOMEDIR/.nomcash/conf/",
		"ModSubs" => [
			sub{my($key,$value)=@_; if( $key=~m/_LIST$/){my @tmp=split /\s+/,$value;return \@tmp } ;return undef},
			sub{my($key,$value)=@_; if( $key=~m/_HASH$/){my %tmp=split /\s+/,$value;return \%tmp } ;return undef}],
		"KeyFileSub" => 
		sub { # KeyFileSub definieren
			my($source,$key,$raw,$modified) = @_; # Argumente einlesen
			return "$NomCash::Info::SANDBOX$NomCash::Info::HOMEDIR/.nomcash/conf/NomCash-$NomCash::Info::USER.conf" unless $source; # Wenn neuer Key, dann in Standardordner 
			return $source; # Sonst wieder zurueck in die gleiche Datei
			},
		);
		
		# Konfiguration laden
		$PCNF = new DataObject \%pcnfarg;
	
	#######################
	### Datenbank laden ###
	#######################
	# Konfiguration fuer die R-Datenbank
		my %rdbarg = (
		"FunctionSource" => "$NomCash::Info::SANDBOX/usr/lib/nomcash/R/", # Ordner fuer die Basis-R-NomCash-Funktionen
		"DataSource" => "$NomCash::Info::SANDBOX$NomCash::Info::HOMEDIR/.nomcash/data/$NomCash::Info::USER-NomCash.noc" # Datendatei des Users
		);
		
		# R-Datenbank laden
		$DATA = new NomCashRDataBase \%rdbarg;
	}


#######################################
### Subroutine, die die GUI startet ###
#######################################
sub Gtk2_start {
	#############################
	#############################
	##### Jetzt GTK2 machen #####
	#############################
	#############################

	# Load the configuration
	&Nomcash_Gtk2_Configuration_init;
	
	Gtk2->init; # Gtk2 initialisieren

	# Startstatistik setzen
	$STAT->increase("GTK_STARTS"); # Starts hochzaehlen

	
	
	#######################
	### Create a Window ###
	#######################
	
	$GTK{Window} = Gtk2::Window->new;
	
	# Set the Title of the Window
	$GTK{Window}->set_title( $LANG->get("WINDOW_TITLE") );
	
	# Set the Border of the Window
	$GTK{Window}->set_border_width(0);
	
	# Set the minimum size of the Window
	$GTK{Window}->set_size_request(800, 400);
	
	# Set the position
	$GTK{Window}->set_position('center');
	
	# Set icon
	$GTK{Window}->set_icon_from_file("$NomCash::Info::SANDBOX/usr/share/nomcash/images/nomcash-icon.png");
	
	# Say what is done if the Window is closed
	$GTK{Window}->signal_connect('destroy' => \&quit_nomcash);
	
	# Say what is done if the Window is closed
	$GTK{Window}->signal_connect('delete-event' => \&quit_nomcash);
	
	
	# Add Keyboard shortcuts
	require Gtk2::Gdk::Keysyms; # Require Keycodes
	$GTK{WindowAccelGroup} = Gtk2::AccelGroup->new(); # Define accelerator group
	$GTK{Window}->add_accel_group( $GTK{WindowAccelGroup} ); # Add accelerator group to main Window
	
	
	
	##############################
	### Window is ready to use ###
	##############################
	
	
	
	
	
	########################
	### Create a MenuBar ###
	########################
	$GTK{MenuBar} = Gtk2::MenuBar->new;
	
	
			###################
			### Menu "File" ###
			###################
			$GTK{MBMenuFile} = Gtk2::Menu->new;
			$GTK{MBFile} = Gtk2::MenuItem->new( $LANG->get("MENUBAR_FILE") );
	
			# Create entries of the "File"-Menu
				# Import entry
				$GTK{MBFileImport}	= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_FILE_IMPORT") );
				$GTK{MBFileImport}->set_image( Gtk2::Image->new_from_stock( $CONF->get("GTK_MENU_FILE_IMPORT_STOCKIMAGE"),"GTK_ICON_SIZE_MENU") );
				# Export entry
				$GTK{MBFileExport}	= Gtk2::ImageMenuItem->new($LANG->get("MENUBAR_FILE_EXPORT"));
				$GTK{MBFileExport}->set_image( Gtk2::Image->new_from_stock( $CONF->get("GTK_MENU_FILE_EXPORT_STOCKIMAGE"),"GTK_ICON_SIZE_MENU") );
				# Save entry
				$GTK{MBFileSave}		= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_FILE_SAVE") );
				$GTK{MBFileSave}->set_image( Gtk2::Image->new_from_stock( $CONF->get("GTK_MENU_FILE_SAVE_STOCKIMAGE"),"GTK_ICON_SIZE_MENU") );
				# Quit entry
				$GTK{MBFileQuit}		= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_FILE_QUIT") );
				$GTK{MBFileQuit}->set_image( Gtk2::Image->new_from_stock( $CONF->get("GTK_MENU_FILE_QUIT_STOCKIMAGE"),"GTK_ICON_SIZE_MENU") );
	
			# Connect them to actions
			$GTK{MBFileImport}->signal_connect('select' => \&showinfo, $LANG->get("MENUBAR_FILE_IMPORT_INFO") );
			$GTK{MBFileImport}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBFileExport}->signal_connect('select' => \&showinfo, $LANG->get("MENUBAR_FILE_EXPORT_INFO") );
			$GTK{MBFileExport}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBFileSave}->signal_connect('select' => \&showinfo,  $LANG->get("MENUBAR_FILE_SAVE_INFO") );
			$GTK{MBFileSave}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBFileSave}->add_accelerator('activate' => $GTK{WindowAccelGroup}, $Gtk2::Gdk::Keysyms{s} , [ 'control-mask' ], [ 'visible' ]); # Connect STRG-S to "Save"-MenuItem
			$GTK{MBFileSave}->signal_connect('activate' => \&save_current_state); # Save the current state
			$GTK{MBFileQuit}->signal_connect('activate' => \&quit_nomcash ); # Quit NomCash
			$GTK{MBFileQuit}->signal_connect('select' => \&showinfo,  $LANG->get("MENUBAR_FILE_QUIT_INFO") );
			$GTK{MBFileQuit}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBFileQuit}->add_accelerator('activate' => $GTK{WindowAccelGroup}, $Gtk2::Gdk::Keysyms{q} , [ 'control-mask' ], [ 'visible' ]); # Connect STRG-Q to "Quit"-MenuItem
	
			# Append them to the "File"-Menu
			$GTK{MBMenuFile}->append($GTK{MBFileImport});
			$GTK{MBMenuFile}->append($GTK{MBFileExport});
			$GTK{MBMenuFile}->append(Gtk2::SeparatorMenuItem->new);
			$GTK{MBMenuFile}->append($GTK{MBFileSave});
			$GTK{MBMenuFile}->append(Gtk2::SeparatorMenuItem->new);
			$GTK{MBMenuFile}->append($GTK{MBFileQuit});
	
			# Show actual Items
			$GTK{MBFileImport}->show;
			$GTK{MBFileExport}->show;
			$GTK{MBFileSave}->show;
			$GTK{MBFileQuit}->show;
	
			# Show the parent "File"-MenuItem
			$GTK{MBFile}->show;
	
			# Connect the elements to the parent "File"-MenuItem
			$GTK{MBFile}->set_submenu($GTK{MBMenuFile});
	
			# Put the "File"-Menu into the Menubar
			$GTK{MenuBar}->append($GTK{MBFile});
	
	
	
			###################
			### Menu "Edit" ###
			###################
			$GTK{MBMenuEdit} = Gtk2::Menu->new;
			$GTK{MBEdit} = Gtk2::MenuItem->new( $LANG->get("MENUBAR_EDIT") );
	
			# Create entries of the "Edit"-Menu
				# New entry with Submenu
				$GTK{MBEditNew}		= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_EDIT_NEW") );
				$GTK{MBEditNew}->set_image( Gtk2::Image->new_from_stock( "gtk-new", "GTK_ICON_SIZE_MENU" ) );
					########################
					### Submenu to "New" ###
					########################
					# Create submenu
					$GTK{MBEditNewSubmenu} = Gtk2::Menu->new;
					# Connect it to "New" MenuItem
					$GTK{MBEditNew}->set_submenu( $GTK{MBEditNewSubmenu} );
					$GTK{MBEditNew}->signal_connect( 'select' => \&showinfo, $LANG->get("MENUBAR_EDIT_NEW_INFO") );
					$GTK{MBEditNew}->signal_connect( 'deselect' => \&stdinfo);
	
					# Create entries for submenu Edit->New->...
						# Edit->New->Entry entry
						$GTK{MBEditNewEntry} = Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_EDIT_NEW_ENTRY") );
						$GTK{MBEditNewEntry}->set_image( Gtk2::Image->new_from_stock("gtk-new", "GTK_ICON_SIZE_MENU") );
						$GTK{MBEditNewEntry}->signal_connect( 'activate' => sub { \&EditingDialogAndSave({TYPE=>'new'}) } );
						$GTK{MBEditNewEntry}->add_accelerator('activate' => $GTK{WindowAccelGroup}, $Gtk2::Gdk::Keysyms{n} , [ 'control-mask' ], [ 'visible' ]); # Connect STRG-S to "Save"-MenuItem

						# Edit->New->Pool entry
						$GTK{MBEditNewPool} = Gtk2::ImageMenuItem->new( $LANG->get( "MENUBAR_EDIT_NEW_POOL" ) );
						$GTK{MBEditNewPool}->set_image( Gtk2::Image->new_from_stock("gtk-new", "GTK_ICON_SIZE_MENU") );
	
						# Edit->New->Person entry
						$GTK{MBEditNewPerson} = Gtk2::ImageMenuItem->new( $LANG->get( "MENUBAR_EDIT_NEW_PERSON" ) );
						$GTK{MBEditNewPerson}->set_image( Gtk2::Image->new_from_stock("gtk-new", "GTK_ICON_SIZE_MENU") );
	
					# Connect "New"-Menuentries to actions
					$GTK{MBEditNewEntry}->signal_connect( 'select' => \&showinfo, $LANG->get("MENUBAR_EDIT_NEW_ENTRY_INFO") );
					$GTK{MBEditNewEntry}->signal_connect( 'deselect' => \&stdinfo);
					$GTK{MBEditNewPool}->signal_connect( 'select' => \&showinfo, $LANG->get("MENUBAR_EDIT_NEW_POOL_INFO") );
					$GTK{MBEditNewPool}->signal_connect( 'deselect' => \&stdinfo);
					$GTK{MBEditNewPerson}->signal_connect( 'select' => \&showinfo, $LANG->get("MENUBAR_EDIT_NEW_PERSON_INFO") );
					$GTK{MBEditNewPerson}->signal_connect( 'deselect' => \&stdinfo);
								
		
					# Add entries to submenu of "New"
					$GTK{MBEditNewSubmenu}->append( $GTK{MBEditNewEntry} );
					$GTK{MBEditNewSubmenu}->append( $GTK{MBEditNewPool} );
					$GTK{MBEditNewSubmenu}->append( $GTK{MBEditNewPerson} );
	
				# Edit->Search entry
				$GTK{MBEditSearch}	= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_EDIT_SEARCH") );
				$GTK{MBEditSearch}->set_image( Gtk2::Image->new_from_stock( "gtk-find","GTK_ICON_SIZE_MENU") );
		
				# Edit->Settings entry
				$GTK{MBEditSettings}	= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_EDIT_SETTINGS") );
				$GTK{MBEditSettings}->set_image( Gtk2::Image->new_from_stock( "gtk-properties","GTK_ICON_SIZE_MENU") );
	
	
			# Connect "Edit"-MenuItems to actions
			$GTK{MBEditSearch}->signal_connect('select' =>  \&showinfo, $LANG->get("MENUBAR_EDIT_SEARCH_INFO") );
			$GTK{MBEditSearch}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBEditSettings}->signal_connect('select' => \&showinfo, $LANG->get("MENUBAR_EDIT_SETTINGS_INFO") );
			$GTK{MBEditSettings}->signal_connect('deselect' => \&stdinfo);
	
			# Append them to the "Edit"-Menu
			$GTK{MBMenuEdit}->append($GTK{MBEditNew});
			$GTK{MBMenuEdit}->append(Gtk2::SeparatorMenuItem->new);
			$GTK{MBMenuEdit}->append($GTK{MBEditSearch});
			$GTK{MBMenuEdit}->append(Gtk2::SeparatorMenuItem->new);
			$GTK{MBMenuEdit}->append($GTK{MBEditSettings});
	
			# Show actual Items
			$GTK{MBEditSearch}->show;
			$GTK{MBEditSettings}->show;
		
			# Show the parent "Edit"-MenuItem
			$GTK{MBEdit}->show;
	
			# Connect the elements to the parent "Edit"-MenuItem
			$GTK{MBEdit}->set_submenu($GTK{MBMenuEdit});
	
			# Put the "Edit"-Menu into the Menubar
			$GTK{MenuBar}->append($GTK{MBEdit});
	
	
	
	
			###################
			### Menu "Help" ###
			###################
			$GTK{MBMenuHelp} = Gtk2::Menu->new;
			$GTK{MBHelp} = Gtk2::MenuItem->new( $LANG->get("MENUBAR_HELP") );
	
			# Create entries of the "Edit"-Menu
			$GTK{MBHelpInfo}	= Gtk2::ImageMenuItem->new( $LANG->get("MENUBAR_HELP_INFO") );
			$GTK{MBHelpInfo}->set_image( Gtk2::Image->new_from_stock( "gtk-dialog-info","GTK_ICON_SIZE_MENU") );
	
			# Connect them to actions
			$GTK{MBHelpInfo}->signal_connect('select' => \&showinfo, $LANG->get("MENUBAR_HELP_INFO_INFO") );
			$GTK{MBHelpInfo}->signal_connect('deselect' => \&stdinfo);
			$GTK{MBHelpInfo}->signal_connect('activate' => \&show_info_window); # Show the Infowindow if clicked
	
			# Append them to the "Edit"-Menu
			$GTK{MBMenuHelp}->append($GTK{MBHelpInfo});
	
			# Show actual Items
			$GTK{MBHelpInfo}->show;
	
			# Show the parent "Edit"-MenuItem
			$GTK{MBHelp}->show;
	
			# Connect the elements to the parent "Edit"-MenuItem
			$GTK{MBHelp}->set_submenu($GTK{MBMenuHelp});
	
			# Put the "Edit"-Menu into the Menubar
			$GTK{MenuBar}->append($GTK{MBHelp});
	
	
	################################
	### MenuBar is ready to use ###
	################################
	
	
	
	
	
	
	##############################
	### Create main Containers ###
	##############################
	
	# Create a VBox to handle the MenuBar and the actual content
	$GTK{MainVBox}		= Gtk2::VBox->new(     FALSE,            0       );
	#                                       not homogenious,  no spacing
	
	# Create a Table for the actual content
	$GTK{MainTable}	= Gtk2::Table->new(     1,         1,           FALSE        );
	#                                      row      columns    not homogenious
	
	# Create a StatusBar
	$GTK{MainStatusBarHBox} = Gtk2::HBox->new( FALSE, 0);
		# Create Labels to pack into the StatusBar
		$GTK{MainStatusBarLeft} = Gtk2::Label->new( $LANG->get("STATUSBAR_STANDARD") ); # Left
		$GTK{MainStatusBarCenter} = Gtk2::Label->new(""); # Center
		$GTK{MainStatusBarRight} = Gtk2::Label->new("");  # Right
	
		# Pack them into the MainStatusBarHBox
		$GTK{MainStatusBarHBox}->pack_start( $GTK{MainStatusBarLeft}, 	FALSE, FALSE, 0 );
		#$GTK{MainStatusBarHBox}->pack_start( Gtk2::VSeparator->new, 	FALSE, FALSE, 0 ); # Maybe add a vertical line...
		$GTK{MainStatusBarHBox}->pack_start( $GTK{MainStatusBarCenter},TRUE, FALSE, 0 );
		$GTK{MainStatusBarHBox}->pack_end  ( $GTK{MainStatusBarRight}, FALSE, FALSE, 0 );
	
	
	########################################
	### Main Containers are ready to use ###
	########################################
	
	
	
	
	
	
	########################
	### Generate Content ###
	########################
	
	
	# Create a Table containing the starting stats
	$GTK{StartStatsTable} = Gtk2::Table->new(2,2,FALSE);
	
		# Create labels to pack into the Table
		$GTK{LabelAmntStartsText} = Gtk2::Label->new;
		$GTK{LabelAmntStartsText}->set_markup($LANG->get("AMNT_STARTS"));
		$GTK{LabelAmntStartsText}->set_alignment( 1, 0.5); # right justify
		$GTK{LabelAmntStarts} = Gtk2::Label->new( $STAT->get("GTK_STARTS")  );
		$GTK{LabelAmntStarts}->set_alignment( 0, 0.5); # left justify
	
	
		$GTK{LabelLastStartText} = Gtk2::Label->new;
		$GTK{LabelLastStartText}->set_markup($LANG->get("LAST_START"));
		$GTK{LabelLastStartText}->set_alignment( 1, 0.5); # right justify
		$GTK{LabelLastStart} = Gtk2::Label->new( $STAT->get("LAST_GTK_START_FORMAT")  );
		$GTK{LabelLastStart}->set_alignment( 0, 0.5); # left justify
		
		# Pack the labels into the Table
		$GTK{StartStatsTable}->attach_defaults( $GTK{LabelLastStartText},		0, 1, 1, 2 );
		$GTK{StartStatsTable}->attach_defaults( $GTK{LabelLastStart},			1, 2, 1, 2 );
		$GTK{StartStatsTable}->attach_defaults( $GTK{LabelAmntStartsText},	0, 1, 2, 3 );
		$GTK{StartStatsTable}->attach_defaults( $GTK{LabelAmntStarts},			1, 2, 2, 3 );
		
		# Show everything in the Table
		$GTK{StartStatsTable}->show_all;
	# Table with starting stats is ready to use

	
	#########################
	### Content generated ###
	#########################
	
	
	
	
	
	################################################
	### Combine/Pack Elements into to the Window ###
	################################################
	
	
		# The MainVBox contains the MenuBar and the MainTable and the StatusBar
		$GTK{MainVBox}->pack_start($GTK{MenuBar}, FALSE, FALSE, 0);

		# Put stuff into the MainTable 
		#$GTK{MainVBox}->pack_start($GTK{StartStatsTable},  FALSE, FALSE, 0);
	
		$GTK{MainVBox}->pack_start($GTK{MainTable}, FALSE, FALSE, 0);
		$GTK{MainVBox}->pack_end  ($GTK{MainStatusBarHBox}, FALSE, FALSE, 0);
		$GTK{MainVBox}->pack_end( Gtk2::HSeparator->new , FALSE, FALSE, 0);
	
		# The Main VBox is finally packed into the Window
		$GTK{Window}->add($GTK{MainVBox});
	
	
	############################################
	### Everything is packed into the Window ###
	############################################
	
	
	# Show everything you have!
	$GTK{Window}->show_all;
	
	
	#####################################
	### Window is shown, now do stuff ###
	#####################################
	
	# Aus Standard-Datei einlesen
	$DATA->NOCreadinit();
	
	# Make a new entry
	#$DATA->NOCsaveentries({ENTRYTIME=>123241235,TIME=>1231414123,MATTER=>'Eintrag vom Skript',AMOUNT=>140,ID=>3});
	
	# Get some data into R
	#$DATA->NOCreadappend(qq`/home/yann/Programmieren/NomCash/ROOT/home/yann/.nomcash/data/extra-NomCash.noc`);


	# Get data into Perl
	#print $DATA->{R}->run(qq`NOCDATA`);
	$DATA->{R}->run(qq`NOCselectall()`);
	#print Dumper $DATA->NOCgetselectedrows;
	
	$GTK{MainTreeView} = &TreeViewFromData({},$DATA->NOCgetselectedrows);
	$GTK{MainTable}->attach_defaults($GTK{MainTreeView}, 0, 1, 0, 1);
	#$GTK{MainTable}->attach_defaults(&TreeViewFromData({},@datasets), 0, 1, 0, 1);

	# Update/initialize the information in the status bar
	&update_status_bar_information_right;

	
	# Now start the GTK main loop
	Gtk2->main;
	
	}


##################################################################
### Sub to open an editing dialog and save the resulting stuff ###
##################################################################
#
# ARGUMENTE 
#	- HASHREF with preferences of EditingDialog {LOCK=>[qw/.../],TEMPLATE={}}
# 	- LIST of datahashes produced with for example NomCash::Base->NOCgetselectedrows
#
sub EditingDialogAndSave {
	my @DATAHASHES = &EditingDialog(@_); # Open the Editing Dialog and save result
	$DATA->NOCsaveentries(@DATAHASHES); # Save the Entries
	&update_status_bar_information_right; # Update what has to do with database information
	}

################################################################
### Produce a TreeView from data taken out of the R Database ###
################################################################
# 
# ARGUMENTE
#	- HASHREF with preferences of TreeView {...}
# 	- LIST of datahashes produced with for example NomCash::Base->NOCgetselectedrows
#
sub TreeViewFromData {
	require Scalar::Util; # Be able to look for things like numbers
	require List::Util; # Be able to find the index of an element in an array
	require POSIX; # Be able to format dates
	my $tmp; my $col; my @tmp; # Temporary variables

	my $PREFS = ref $_[0] eq 'HASH' ? shift : {}; # First argument is the configuration hash for the treeview
	my @alldatahashes = grep { ref $_ eq 'HASH' } @_; # Take every argument that is a hash

	# This is the hash that holds information on markup and justification of Columns
	my $ColumnsMarkupFormatHash = $CONF->get("COLUMNS_MARKUP_FORMAT_HASHOFLISTS"); # Read from conffile
	$ColumnsMarkupFormatHash = {} unless ref $ColumnsMarkupFormatHash eq "HASH"; # Let it be a hashref if not

	######################################
	### Adjust the content of the data ###
	######################################
	# and get all available header columns
	$tmp = {};
	my $aktentry; my $columnsheaderformathash; my $aktdataset; 
	# Take all datasets you were given
	foreach my $aktdataset ( @alldatahashes ) { # $aktdataset is the actual datahash
		foreach my $headerkey (keys $aktdataset) {
			$tmp->{$headerkey} = 1; # Define the actual header element in a hash
			$aktentry = $aktdataset->{$headerkey}; # Jetzigen Eintrag zwischenspeichern

			# Gucken, ob Eintrag formatiert werden soll
			my $columns_format_hash = $CONF->get("COLUMNS_FORMAT_HASH");
			if(exists $columns_format_hash->{$headerkey}) {
				# Formatiere Einträge, wenn in Konfigurationsdatei angegeben
				if($columns_format_hash->{$headerkey} eq 'money') {
					####################
					### Money Format ###
					####################
					my $currencysign = eval {$LANG->get("CURRENCY_SIGN") or "" };
					if(Scalar::Util::looks_like_number($aktentry)) {
						$aktdataset->{$headerkey."_FORMAT"} = sprintf "%.2f $currencysign", $aktentry / 100; }
					else {  # If the money field is rubbish, then use 0
						$aktdataset->{$headerkey} = 0;
						$aktdataset->{$headerkey."_FORMAT"} = sprintf "%.2f $currencysign", 0.0;
						}
					}
				elsif($columns_format_hash->{$headerkey} eq 'date') {
					###################
					### Date Format ###
					###################
					if (Scalar::Util::looks_like_number($aktentry)){ # Only format it if it is numeric
						$aktdataset->{$headerkey."_FORMAT"} = POSIX::strftime "%a, %d.%m.%Y", localtime($aktentry+0);} 
					else { # If the date-field is rubbish, then undef it, that the TreeStore does not croak
						$aktdataset->{$headerkey} = undef;
						$aktdataset->{$headerkey."_FORMAT"} = "" }
					}
				elsif($columns_format_hash->{$headerkey} eq 'copy') {
					###############################
					### Just copy the base text ###
					###############################
					$aktdataset->{$headerkey."_FORMAT"} = $aktdataset->{$headerkey};
					}

				$tmp->{$headerkey."_FORMAT"} = 1; # Define the formatted header element in a hash
				}

			####################
			### Apply Markup ###
			####################
			# Only apply to the formatted entry, never to base!
			my $MarkupList = $ColumnsMarkupFormatHash->{$headerkey."_FORMAT"} if exists $ColumnsMarkupFormatHash->{$headerkey."_FORMAT"};
			if( ref $MarkupList eq "ARRAY" ) { # Only if its arrayref, not if undef or anything else
				foreach my $Markup ( @$MarkupList ) { # Iterate over all given markup definitions
					if($Markup eq 'bold') ### Bold text ###
						{ $aktdataset->{$headerkey."_FORMAT"} = "<b>".$aktdataset->{$headerkey."_FORMAT"}."</b>"; }
					elsif($Markup eq 'italic') ### Bold text ###
						{ $aktdataset->{$headerkey."_FORMAT"} = "<i>".$aktdataset->{$headerkey."_FORMAT"}."</i>"; }
					}
				}
			}
		}
	

	# The @headercomplete list is a list of the maximum available header elements from the given data hashes
	my @headercomplete = keys $tmp; # !!!Caution!!! The order of the header elements gets messes up here, just fyi!
	my $anzcols = scalar @headercomplete; # Get amount of columns

	# Print for debugging
	#print Data::Dumper::Dumper \@headercomplete;
	#print Data::Dumper::Dumper \@alldatahashes;


	#################################################
	### Show only a label if no data is available ###
	#################################################
	# Is there anything to show?
	# If not, then just return a label
	if($anzcols == 0) {
		my $label = Gtk2::Label->new; # Create new label
		my $text = $LANG->get("TREEVIEW_NO_DATASET_FOUND"); # Retrieve the text from languagefile
		$label->set_markup($text); # Set the text with markup
		$label->show; # Show the label
		return $label; # Return it
		}


	#############################
	### Read the column types ###
	#############################
	# Find out which type each column has
	my %columntypes;
	$tmp = $CONF->get("COLUMNS_DATA_TYPES_HASH"); $tmp = {} unless ref $tmp eq 'HASH'; # Get configurated column types
	foreach my $headerkey (@headercomplete) {
		# Was the data type defined?
		if(exists $tmp->{$headerkey}) {
			if	   ($tmp->{$headerkey} eq 'string' ) { $columntypes{$headerkey} = "Glib::String" }
			elsif	($tmp->{$headerkey} eq 'integer') { $columntypes{$headerkey} = "Glib::Int"    }
			elsif	($tmp->{$headerkey} eq 'double' ) { $columntypes{$headerkey} = "Glib::Double" }
			else                                    { $columntypes{$headerkey} = "Glib::String" }
			}
		# If the data type was not specified, suppose String
		else { $columntypes{$headerkey} = 'Glib::String' }
		}


	##########################
	### Create a TreeStore ###
	##########################
	my $TreeStore = Gtk2::TreeStore->new( @columntypes{@headercomplete} ); # Define columns of TreeStore

	# Fill the TreeStore with data
	foreach my $aktdataset ( @alldatahashes ) {
		my @datalist = map { # Map over all Columns in the TreeStore
			# Return (Column-number, String)
			($_,$aktdataset->{$headercomplete[$_]}); # Column-Nr and Dataset pair
			} 0 .. $TreeStore->get_n_columns-1;
		$TreeStore->set( # Fill one line of the TreeStore
			$TreeStore->append(undef), # Append to TreeStore by new TreeIter
			@datalist # Insert the datalist created above
			);
		}

	#my $SortedTreeStore = Gtk2::TreeModelSort->new($TreeStore); # Create a sorted TreeModel from the TreeStore

	# Print everything in the TreeStore, for debugging purposes
	#my $iter = $TreeStore->get_iter_first; do { print map { $headercomplete[$_],": ",$TreeStore->get($iter, $_),"\n" } 0..$TreeStore->get_n_columns-1 } while($iter = $TreeStore->iter_next($iter));

	#########################
	### Create a TreeView ###
	#########################
	# Create a treeview and tweak it
	my $TreeView = Gtk2::TreeView->new($TreeStore);
	$TreeView->set_property('rules-hint' => TRUE); # Tell the theme engine to draw lines in alternating background colors
	$TreeView->set_property('rubber-banding' => TRUE); # Enable rubber-banding, does not make sense with multiple-selection
	$TreeView->get_selection->set_mode('multiple'); # Allow multiple selection
	$TreeView->show; # Show the treeview


	#################################
	### Popup Menu at right-click ###
	#################################
	# TODO: Only show menu if $PREFS->{...} was set
	$TreeView->signal_connect('button-press-event' => sub { 
		my ($TreeView,$Event) = @_;
		unless ($Event->button==1 or $Event->button==3) { return FALSE }

		# Convert Selected to Hash
		my $TreeStore = $TreeView->get_model; # The TreeStore
		my $AnzSelected = $TreeView->get_selection->count_selected_rows; # The amount of selected rows
		my @Selected = $TreeView->get_selection->get_selected_rows; # List of TreePaths
		@Selected = map { $TreeStore->get_iter($_) } @Selected; # Convert TreePaths to TreeIters

		my @HashList; # Determine Hashes from selected Rows, but only take non-formatted fields
		foreach my $Iter (@Selected) { # Take all Gtk2::TreeIters you got from the selection
			my %EntryHash = map {($_,1)} @headercomplete; # Create Entry Hash only with header elements
			@EntryHash{@headercomplete} = $TreeStore->get($Iter); # Put the selected row into this hash
			map { delete $EntryHash{$_} if m/_FORMAT$/ } keys %EntryHash; # Take only non-formatted header elements
			push @HashList, \%EntryHash; # Append this hash to the List of selected hashes
			}

		#################################
		### Double Left-click -> Edit ###
		#################################
		if($Event->button==1 and $Event->type eq "2button-press") {
				&EditingDialogAndSave({},@HashList); # Edit and save!
				return TRUE; # We handled the event	
				}

		###########################
		### Right-click -> Menu ###
		###########################
		if($Event->button==3) { # It's a right-click
			# Select the right-clicked row as well
			my ($RightClicked,undef) = $TreeView->get_path_at_pos($Event->x,$Event->y); # Get clicked row
			$TreeView->get_selection->select_path($RightClicked); # Select the row
			my $TreeStore = $TreeView->get_model; # The TreeStore
			my $AnzSelected = $TreeView->get_selection->count_selected_rows; # The amount of selected rows
			my @Selected = $TreeView->get_selection->get_selected_rows; # List of TreePaths
			@Selected = map { $TreeStore->get_iter($_) } @Selected; # Convert TreePaths to TreeIters

			my @HashList; # Determine Hashes from selected Rows, but only take non-formatted fields
			foreach my $Iter (@Selected) { # Take all Gtk2::TreeIters you got from the selection
				my %EntryHash = map {($_,1)} @headercomplete; # Create Entry Hash only with header elements
				@EntryHash{@headercomplete} = $TreeStore->get($Iter); # Put the selected row into this hash
				map { delete $EntryHash{$_} if m/_FORMAT$/ } keys %EntryHash; # Take only non-formatted header elements
				push @HashList, \%EntryHash; # Append this hash to the List of selected hashes
				}
			###########################
			### Create a popup Menu ###
			###########################
			# But only if elements are selected
			if (scalar @Selected > 0) {
				my %Menu; $Menu{Menu} = Gtk2::Menu->new; # Create Menu
				my $StockImageName;
				# Create Edit Item
				$Menu{MenuEdit} = Gtk2::ImageMenuItem->new( $LANG->get("TREEVIEW_POPUP_MENU_EDIT_TEXT") );
				$StockImageName = eval { $CONF->get('TREEVIEW_POPUP_MENU_EDIT_STOCKID') or 'gtk-edit' };
				$Menu{MenuEdit}->set_image( Gtk2::Image->new_from_stock($StockImageName,'menu') );
				$Menu{MenuEdit}->signal_connect('select' => \&showinfo, $LANG->get("TREEVIEW_POPUP_MENU_EDIT_INFO") );
				$Menu{MenuEdit}->signal_connect('deselect' => \&stdinfo);
				# The EditingDialog will be showed if clicked and save what results of this
				{ # Open new Block to prevent value-messing with references
				my @CapsuledHashList = map { { %$_ } } @HashList; # Deref all elements
				$Menu{MenuEdit}->signal_connect('activate' => sub {&EditingDialogAndSave({},@CapsuledHashList)}); # Show the Editing Dialog if clicked
				}
			
				# Create Delete Item
				$Menu{MenuDelete} = Gtk2::ImageMenuItem->new( $LANG->get("TREEVIEW_POPUP_MENU_DELETE_TEXT") );
				$StockImageName = eval { $CONF->get('TREEVIEW_POPUP_MENU_DELETE_STOCKID') or 'gtk-delete' };
				$Menu{MenuDelete}->set_image( Gtk2::Image->new_from_stock($StockImageName,'menu') );
				$Menu{MenuDelete}->signal_connect('select' => \&showinfo, $LANG->get("TREEVIEW_POPUP_MENU_DELETE_INFO") );
				$Menu{MenuDelete}->signal_connect('deselect' => \&stdinfo);
				{ # Open new Block to prevent value-messing with references
				my @CapsuledHashList = map { { %$_ } } @HashList; # Deref all elements
				# Delete if clicked
				$Menu{MenuDelete}->signal_connect('activate' => sub { &delete_hashes_from_database(@CapsuledHashList); });
				}
			
				# Create Copy Item
				$Menu{MenuCopy} = Gtk2::ImageMenuItem->new( $LANG->get("TREEVIEW_POPUP_MENU_COPY_TEXT") );
				$StockImageName = eval { $CONF->get('TREEVIEW_POPUP_MENU_COPY_STOCKID') or 'gtk-copy' };
				$Menu{MenuCopy}->set_image( Gtk2::Image->new_from_stock($StockImageName,'menu') );
				$Menu{MenuCopy}->signal_connect('select' => \&showinfo, $LANG->get("TREEVIEW_POPUP_MENU_COPY_INFO") );
				$Menu{MenuCopy}->signal_connect('deselect' => \&stdinfo);
				# The EditingDialog will be showed if clicked, but all results should be saved as NEW entries
				# Thus the ID key has to be removed from the entries
				# TODO: Anonymise the ID key
				{ # Open new Block to prevent value-messing with references
				my @CapsuledHashList = map { { %$_ } } @HashList; # Deref all elements
				my @HashListWithoutID = map { delete $_->{ID};$_ } @CapsuledHashList; # Remove ID keys
				$Menu{MenuCopy}->signal_connect('activate' => sub {&EditingDialogAndSave({},@HashListWithoutID)}); # Show the Editing Dialog if clicked
				}
			
				# Create Split Item, but only if just one row was selected
				if(scalar @Selected == 1) {
					$Menu{MenuSplit} = Gtk2::ImageMenuItem->new( $LANG->get("TREEVIEW_POPUP_MENU_SPLIT_TEXT") );
					$StockImageName = eval { $CONF->get('TREEVIEW_POPUP_MENU_SPLIT_STOCKID') or 'gtk-copy' };
					$Menu{MenuSplit}->set_image( Gtk2::Image->new_from_stock($StockImageName,'menu') );
					$Menu{MenuSplit}->signal_connect('select' => \&showinfo, $LANG->get("TREEVIEW_POPUP_MENU_SPLIT_INFO") );
					$Menu{MenuSplit}->signal_connect('deselect' => \&stdinfo);
					# The EditingDialog will be showed if clicked with locked fields
					# Find out current ID of selected row
					my $Group; my $DataSetToSplit={ %{$HashList[0]} };
					if(exists $DataSetToSplit->{ID} and Scalar::Util::looks_like_number($DataSetToSplit->{ID})) # Everyting ok, ID exists as is should
						{ $Group = $DataSetToSplit->{ID}+0 }
					else { $Group = 0 } # TODO: Use next group number / next ID as group number
					delete $DataSetToSplit->{ID};
					$DataSetToSplit->{GROUP} = $Group; # Use current ID as Group
					$Menu{MenuSplit}->signal_connect('activate' => sub {&EditingDialogAndSave({LOCK=>[qw/TIME ENTRYTIME SOURCE TARGET ID GROUP/],TEMPLATE=>{GROUP=>$Group}},$DataSetToSplit)}); # Show the Editing Dialog with Locked elements if clicked
					}
			
				# Append Elements to Menu
				$Menu{Menu}->append( $Menu{MenuEdit} );
				$Menu{Menu}->append( $Menu{MenuCopy} );
				$Menu{Menu}->append( $Menu{MenuSplit} ) if exists $Menu{MenuSplit};
				$Menu{Menu}->append( $Menu{MenuDelete} );
	
				$Menu{Menu}->show_all; # Show everything in the menu
				$Menu{Menu}->popup(undef, undef, undef, undef, $Event->button, $Event->time); # Popup the menu
				}

			return TRUE; # We handled the event!
			}
		return FALSE; # Tell the Handler to handle the event himself
		});


	#############################
	### Connect to Delete-Key ###
	#############################
	$TreeView->signal_connect('key-press-event' => sub { 
		require Gtk2::Gdk::Keysyms; # Know the keycodes
		my ($TreeView,$Event) = @_;

		# Convert TreeStore iters to hashes
		my $TreeStore = $TreeView->get_model; # The TreeStore
		my $AnzSelected = $TreeView->get_selection->count_selected_rows; # The amount of selected rows
		my @Selected = $TreeView->get_selection->get_selected_rows; # List of TreePaths
		@Selected = map { $TreeStore->get_iter($_) } @Selected; # Convert TreePaths to TreeIters

		my @HashList; # Determine Hashes from selected Rows, but only take non-formatted fields
		foreach my $Iter (@Selected) { # Take all Gtk2::TreeIters you got from the selection
			my %EntryHash = map {($_,1)} @headercomplete; # Create Entry Hash only with header elements
			@EntryHash{@headercomplete} = $TreeStore->get($Iter); # Put the selected row into this hash
			map { delete $EntryHash{$_} if m/_FORMAT$/ } keys %EntryHash; # Take only non-formatted header elements
			push @HashList, \%EntryHash; # Append this hash to the List of selected hashes
			}

		#############################
		### Delete Key --> Delete ###
		#############################
		if($Event->keyval == $Gtk2::Gdk::Keysyms{Delete}) { # Delete was pressed
			&delete_hashes_from_database(@HashList); # Delete!
			return TRUE; # We handled the event!
			}
			
		##########################
		### Enter Key --> Edit ###
		##########################
		elsif($Event->keyval == $Gtk2::Gdk::Keysyms{Return}) { # Delete was pressed
			&EditingDialogAndSave({},@HashList); # Edit and save!
			return TRUE; # We handled the event!
			}

		#######################
		### F2 Key --> Edit ###
		#######################
		elsif($Event->keyval == $Gtk2::Gdk::Keysyms{F2}) { # Delete was pressed
			&EditingDialogAndSave({},@HashList); # Edit and save!
			return TRUE; # We handled the event!
			}
		return FALSE; # Tell the Handler to handle the event himself
		});


	# Sort out Columns that are to be displayed
	my %headerhash; foreach (0..$anzcols-1) { $headerhash{$headercomplete[$_]}=$_ }; # Produce a headerhash $headerhash{Colname}->"Colnumber"
	$tmp = $CONF->get("COLUMNS_SHOW_LIST"); # Read columns to show from conffile
	my @columnstoshow = ref $tmp eq "ARRAY" ? grep {exists $headerhash{$_}} @$tmp : @headercomplete; # use all elements that really are in the header 
	
	# Read column titles
	my $columntitles = $LANG->get("TABLE_COLUMN_NAMES_HASH"); # Read column titles from conffile
	$columntitles = {} unless ref $columntitles eq "HASH"; # Make sure it is a hashref

	# Read the tooltips for the tableheaders
	my $columnheadertooltips = $LANG->get("TABLE_COLUMN_TOOLTIPS_HASH"); # Read column titles from conffile
	$columnheadertooltips = {} unless ref $columnheadertooltips eq "HASH"; # Make sure it is a hashref

	my $TreeCol; my $title; my $headerlabel; my $columnid; my $sortcolumn; my $renderer; # Variables for TreeViewColumn content
	foreach my $column (@headerhash{@columnstoshow}) {
		# Find out column id title
		$columnid = $headercomplete[$column];

		# Set FormatHash Value to empty arrayref if not existant
		$ColumnsMarkupFormatHash->{$columnid} = [] unless exists $ColumnsMarkupFormatHash->{$columnid};

		# Determine the Column title
		$title = exists $columntitles->{$columnid} ? $columntitles->{$columnid} : $columnid;

		# Create a TreeViewColumn and tweak it
		$TreeCol = Gtk2::TreeViewColumn->new;
		$TreeCol->set_resizable(TRUE); # Make the Columns resizable
		$TreeCol->set_clickable(TRUE); # Set Column clickable
		$TreeCol->set_reorderable(TRUE); # Set the TreeViewColumn reorderable


		# Organize the headerlabel
		$headerlabel = Gtk2::Label->new; $headerlabel->set_markup($title);
		$headerlabel->set_tooltip_text($columnheadertooltips->{$columnid}) if exists $columnheadertooltips->{$columnid};
		$headerlabel->show;

		# Add the headerlabel to treecolumn
		$TreeCol->set_widget($headerlabel);

		# TODO: Fix this!
		# Initially sort the column specified in conffiles, at the moment, the signal emitting works,
		# for some reason it does this twice, but the treeview is not sorted... don't know why...
		$TreeCol->clicked if $columnid eq $CONF->get("TREEVIEW_INITIAL_SORT_COLUMN");


		# Create and add a Cellrenderer to treecolumn
		$renderer = Gtk2::CellRendererText->new; # The renderer is a text renderer
		$renderer->set_property("xalign",1) if List::Util::first { $_ eq 'right-justified' } @{$ColumnsMarkupFormatHash->{$columnid}}; # Right-justify, if necessary
		$renderer->set_property('wrap-mode','word'); # Set word wrap
		$TreeCol->pack_start($renderer, TRUE); # Add the renderer to the TreeViewColumn
		
		# Tell the TreeViewColumn to retrieve its markup text from the TreeStore column $column
		$TreeCol->add_attribute($renderer, "markup" => $column);

		# Tell the TreeViewColumn which column to use for sorting
		# That column has to be either the same column $column or another with sensible content to sort
		$TreeCol->set_sort_column_id($column); # Set the standard underlying sorting column id
		if($columnid =~ m/_FORMAT$/) {
			$tmp = $columnid; $tmp =~ s/_FORMAT$//; # Remove the trailing "_FORMAT" if existing at all
			$sortcolumn = List::Util::first { $headercomplete[$_] eq $tmp } 0..$anzcols-1; # The sorting column is that one without the trailing "_FORMAT"
			#print "$columnid has sortcolumn $sortcolumn, which is $headercomplete[$sortcolumn]\n";
			$TreeCol->set_sort_column_id($sortcolumn) if defined $sortcolumn; # Set the sort column if one was found
			}

		# Automatic re-wrapping of text at resizing
		#$TreeCol->signal_connect('notify::width',sub{ 
		#	my ($TreeCol,$Param,$Renderer) = @_; # Arguments
		#	$Renderer->set_property('wrap-width',$TreeCol->get_width); # Wrap-width is width of TreeViewColumn
		#	$Renderer->set_property('width',$TreeCol->get_width); # Wrap-width is width of TreeViewColumn
		#	}, 
		#	$renderer); # Extra Argument is the CellRendererText

		# Append the column to the treeview
		$TreeView->append_column($TreeCol);
 		}

	# TODO: Save the users choice
	# Connect to columns-changed signal to save the users choice
	#$TreeView->signal_connect('columns-changed'=>sub{print "Columns changed!\n"});

	return $TreeView; # Return the treeview
	}



######################
### Editing dialog ###
######################
# Open an editing dialog 
# Takes string as first argument specifying the type of the dialog, either 'new' or 'edit'
# Then open a dialog with tabs with templates of residual arguments
# When user clicks on save button, return adjusted hashes in list context
# 
# ARGUMENTE
#
#  - HASHREF   with parameters (LOCK[Arrayref with field names, that are to be set uneditable],TEMPLATE{Hashref as usual that is taken as template for new tabs})
#	- LIST      of Datahashes as produced by NomCash::Base->NOCgetselectedrows for example
#
sub EditingDialog {
	require Scalar::Util; # Be able to look for things like numbers
	require List::Util; # Be able to use first
	my $PREFS = shift; # The first argument is the configuration hash of editing dialog
	# Make sure the required elements exist at last
	$PREFS = {} unless ref $PREFS eq "HASH"; 
	$PREFS->{TEMPLATE} = {} unless (exists $PREFS->{TEMPLATE} or ref $PREFS->{TEMPLATE} ne "HASH");
	$PREFS->{LOCK} = [] if (not exists $PREFS->{LOCK} or ref $PREFS->{LOCK} ne "ARRAY");
	my %LockHash = map {($_,1)} @{$PREFS->{LOCK}}; # Make a Hashref for easy lookup
	$PREFS->{LOCK} = \%LockHash; # Set the LockHash back to the configuration hash
	$PREFS->{TYPE} = '' if (not exists $PREFS->{TYPE} or ref $PREFS->{TYPE} ne ''); # Make sure TYPE is string

	# The rest of the arguments are the datahashes
	my @GIVENDATAHASHES = @_; # This is the list of all datahashes
	@GIVENDATAHASHES = ( $PREFS->{TEMPLATE} ) if scalar @GIVENDATAHASHES == 0; # Put an empty hash into the list if necessary
	#print Dumper @GIVENDATAHASHES;
	
	my $tmp; # Temporary variable
	my %DIALOG; # Hash for elements of the dialog

	# Read the Field from conffile which should be used for tab title adjustment
	my $TabTitleField = $CONF->get("EDITDIALOG_FORM_TAB_TITLE_ENTRY");

	#######################
	### Read properties ###
	#######################
	# Read the types of the elements
	my $ElementTypes = $CONF->get("EDITDIALOG_FORM_TYPES_HASH");
	$ElementTypes = {} unless ref $ElementTypes eq 'HASH';

	# Read the order of the elements
	my $ElementOrder = $CONF->get("EDITDIALOG_FORM_ORDER_LIST");
	$ElementOrder = [] unless ref $ElementOrder eq 'ARRAY';

	# Read the Labels
	my $ElementLabels = $LANG->get("EDITDIALOG_SECTION_TEXT_HASH");
	$ElementLabels = {} unless ref $ElementLabels eq 'HASH';

	# Determine the Type of the Dialog and set Title, Image and Headline text
	my $DialogTitle; my $DialogImage; my $DialogHeadLine;
	if(exists $PREFS->{TYPE}) {
		if($PREFS->{TYPE} eq 'new') { # New entries should be made
			$DialogTitle = $LANG->get("EDITDIALOG_NEW_TITLE");
			$DialogImage = $CONF->get("EDITDIALOG_NEW_HEAD_ICON");
			$DialogHeadLine = $LANG->get("EDITDIALOG_NEW_HEAD_TEXT");
			}
		elsif($PREFS->{TYPE} eq 'edit') { # entries should be edited
			$DialogTitle = $LANG->get("EDITDIALOG_EDIT_TITLE");
			$DialogImage = $CONF->get("EDITDIALOG_EDIT_HEAD_ICON");
			$DialogHeadLine = $LANG->get("EDITDIALOG_EDIT_HEAD_TEXT");
			}
		elsif($PREFS->{TYPE} eq 'split') { # an entry should be split in others
			$DialogTitle = $LANG->get("EDITDIALOG_SPLIT_TITLE");
			$DialogImage = $CONF->get("EDITDIALOG_SPLIT_HEAD_ICON");
			$DialogHeadLine = $LANG->get("EDITDIALOG_SPLIT_HEAD_TEXT");
			}
		else { # Assume Editing
			$DialogTitle = $LANG->get("EDITDIALOG_NO_DATA_TITLE");
			$DialogImage = $CONF->get("EDITDIALOG_NO_DATA_HEAD_ICON");
			$DialogHeadLine = $LANG->get("EDITDIALOG_NO_DATA_HEAD_TEXT");
			}
		}

	# Create the Dialog
	$DIALOG{Dialog} = Gtk2::Dialog->new(
		$DialogTitle, # Title
		$GTK{Window}, # Main Window is parent
		[qw/modal destroy-with-parent/], # Flags
		$LANG->get("EDITDIALOG_BUTTON_SAVE") => 'yes', # Button1
		$LANG->get("EDITDIALOG_BUTTON_CANCEL") => 'no', # Button2
		);

	# Get the VBox to pack the text into
	$DIALOG{DialogVBox} = $DIALOG{Dialog}->vbox; 

	# Create a header with icon and headline
	$DIALOG{DialogHeadHBox} = Gtk2::HBox->new( FALSE, 0 ); # An HBox to hold an icon and the text
	$DialogImage = 'gtk-edit' unless $DialogImage; # If the icon is not defined in the conffile
	$DIALOG{DialogHeadHBox}->pack_start(Gtk2::Image->new_from_stock($DialogImage,'dialog'), TRUE, FALSE, 10); # Add an Icon
	$DIALOG{DialogHeadLabel} = Gtk2::Label->new;
	$DIALOG{DialogHeadLabel}->set_markup( $DialogHeadLine );
	$DIALOG{DialogHeadHBox}->pack_start($DIALOG{DialogHeadLabel}, TRUE, FALSE, 10); # Add text
	$DIALOG{DialogHeadHBox}->show_all; # Show everything in the HBox

	# Put the HBox into the Vbox
	$DIALOG{DialogVBox}->pack_start($DIALOG{DialogHeadHBox}, FALSE, FALSE,10); 


	# Create a NoteBook for Tabs and tweak it
	$DIALOG{DialogNoteBook} = Gtk2::Notebook->new;
	$DIALOG{DialogNoteBook}->set_scrollable(TRUE); # Set scrollable
	$DIALOG{DialogNoteBook}->popup_enable; # Enable popup
	$DIALOG{DialogNoteBook}->set_border_width(0); # Set border
	$DIALOG{DialogNoteBook}->set_tab_border(0); # Set border

	#############################################################
	### Sub to create the needed elements for inside the tabs ###
	#############################################################
	my $CreateTableHash = sub {
		my $GIVENHASH = shift; # Read the given datahash
		$GIVENHASH = {} unless ref $GIVENHASH; # Make sure it's a hash
	
		# This is the hash that will hold all information on the current tab
		my $HASH = {};

		# This is the hash to hold the Labels of the entry elements
		$HASH->{LABELS} = {};

		# This is the hash to hold the changable elements
		$HASH->{ELEMENTS} = {};

		# This is the hash to hold the Widgets which contain the saveable text
		$HASH->{RESENTRIES} = {};

		# This is the Table                      ROWS             COLS HOMOGENIOUS
		$HASH->{TABLE} = Gtk2::Table->new( scalar @{$ElementOrder}, 2, FALSE );

		# This is the hash that holds the Notebook-Tab-Label elements
		$HASH->{TAB} = {};

		#################
		### Tab Title ###
		#################
		# Define main elements for the Tab title
		$HASH->{TAB}->{HBox}  = Gtk2::HBox->new(FALSE,0); # Define a HBox
		$HASH->{TAB}->{Label} = Gtk2::Label->new; # Define a Label
		$HASH->{TAB}->{Button} = Gtk2::Button->new; # Define a Button
		$HASH->{TAB}->{MenuLabel} = Gtk2::Label->new; # Define the MenuLabel for the Tab

		# Find out the title of the Tab
		if (exists $GIVENHASH->{$TabTitleField}) {
			$HASH->{TAB}->{Label}->set_markup("<b>".$GIVENHASH->{$TabTitleField}."</b>") ; 
			$HASH->{TAB}->{MenuLabel}->set_markup("<b>".$GIVENHASH->{$TabTitleField}."</b>") ; 
			} else {
			$HASH->{TAB}->{Label}->set_markup("<b>".$LANG->get("EDITDIALOG_NOTEBOOK_TAB_TEXT_IF_NO_COLUMN_FIELD")."</b>");
			$HASH->{TAB}->{MenuLabel}->set_markup("<b>".$LANG->get("EDITDIALOG_NOTEBOOK_TAB_TEXT_IF_NO_COLUMN_FIELD")."</b>");
			}
		$HASH->{TAB}->{Label}->set_alignment( 0.5, 0.5 ); #
		$HASH->{TAB}->{MenuLabel}->set_alignment( 0, 0.5 ); #

		# Create the Close-Button and tweak it
		# Read the Button Image from conffile or use predifined one
		$HASH->{TAB}->{Button}->set_image(Gtk2::Image->new_from_stock( eval { $CONF->get('EDITDIALOG_NOTEBOOK_CLOSE_STOCK_ICON') or 'gtk-close' } , 'menu'));
		$HASH->{TAB}->{Button}->set_relief('none');

		# Add Label and Button to HBox
		$HASH->{TAB}->{HBox}->pack_start( $HASH->{TAB}->{Label}, TRUE, TRUE, 0 );
		$HASH->{TAB}->{HBox}->pack_end( $HASH->{TAB}->{Button}, FALSE, FALSE, 0 );

		$HASH->{TAB}->{HBox}->show_all; # Show everything in the HBox


		###################################################
		### Create elements and put them into the Table ###
		###################################################
		# Every Section defined to be displayed (in the conffile) should be displayed
		# Every Section in the given hash that should not be displayed should be used in the RESENTRY hash
		# Thus, we have to loop over the union of all given Sections and the Sections to be displayed
		my @AllSectionsToInclude;
		{ # Calculate the union 
		my %hash; # Temoporary hash
		foreach (@{$ElementOrder},keys $GIVENHASH) { 
			push @AllSectionsToInclude, $_ unless exists $hash{$_}; # Only add, if not already added
			$hash{$_}++; # Count the key up
			}; 
		}


		my $count = 0; # Counter for right position in Table
		# Fill the Hashes up
		foreach my $Section (@AllSectionsToInclude) { # Iterate over all elements that are to be displayed
			my $ShowInTable = TRUE; # Should the current Section be showed in the Table? Must be FALSE if it's a hidden Element
			# Define the Label
			$HASH->{LABELS}->{$Section} = Gtk2::Label->new; # Create the Label
			$HASH->{LABELS}->{$Section}->set_markup( $ElementLabels->{$Section} ) if exists $ElementLabels->{$Section}; # Set the text
			$HASH->{LABELS}->{$Section}->set_alignment( 1, 0.5 ); # Right-justify


			###################################################
			### Decide which Widget to take for the section ###
			###################################################
			if(exists $ElementTypes->{$Section}) {
				#######################
				### Calendar Widget ###
				#######################
				if($ElementTypes->{$Section} eq 'calendar') {
					require Time::Local; # Be able to convert to epoch seconds
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field

					# Read the date for the calendar, use current date if not well-defined
					my @DateList = localtime( (exists $GIVENHASH->{$Section} and Scalar::Util::looks_like_number($GIVENHASH->{$Section})) ? $GIVENHASH->{$Section} : time );

					# Split Datelist into Parts 
					my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst)=@DateList; 

					# Should this field be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						my $DateFormatted = POSIX::strftime "%a, %d.%m.%Y", @DateList; # Define text to display
						my $Seconds = Time::Local::timelocal(0,0,0,$mday,$month,$year); # Get Epoch seconds
						# Define Label to use instead of Entry field
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($DateFormatted);
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($Seconds);
						}
					# Field is not locked
					else { 
						# Define a sub to save the calendar date in the ResEntry Field
						my $SaveCalendarDateInResEntry = sub {
							my $calendar = shift; # Calendar is the first argument
							my ($year,$month,$day) = $calendar->get_date; # Get the calendar date
							my $seconds = Time::Local::timelocal(0,0,0,$day,$month,$year); # Get Epoch seconds
							$HASH->{RESENTRIES}->{$Section}->set_text($seconds);
							};
						# Define a calendar
						$HASH->{ELEMENTS}->{$Section} = Gtk2::Calendar->new;
						$HASH->{ELEMENTS}->{$Section}->signal_connect('day-selected'=>$SaveCalendarDateInResEntry);
	
						# Select the date
						$HASH->{ELEMENTS}->{$Section}->select_day($mday);
						$HASH->{ELEMENTS}->{$Section}->select_month($month,$year+1900);
						$HASH->{ELEMENTS}->{$Section}->set_property('show-week-numbers',TRUE); # Show week numbers
						}
					}
				########################
				### Simple Text Line ###
				########################
				elsif($ElementTypes->{$Section} eq 'text-line') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field
					# Field should be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						my $Text=""; $Text = $GIVENHASH->{$Section} if exists $GIVENHASH->{$Section}; # Determine text
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($Text); # Label
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($Text); # Resentry
						}
					# Field not locked
					else {
						# Define an Entry textfield
						$HASH->{ELEMENTS}->{$Section} = Gtk2::Entry->new;
						$HASH->{ELEMENTS}->{$Section}->signal_connect('changed'=>sub{ 
							my $Entry = shift; # Argument is Entry
							my $Text = $Entry->get_text; # Get text
							$Text =~ s/\n//g; # Remove newlines, if any
							$HASH->{RESENTRIES}->{$Section}->set_text( $Text );
							});
						$HASH->{ELEMENTS}->{$Section}->set_text( $GIVENHASH->{$Section} ) if exists $GIVENHASH->{$Section};
						}	
					}
				##########################
				### ComboBox Selection ###
				##########################
				elsif($ElementTypes->{$Section} eq 'selection') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field

					# Field should be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						my $Text=""; $Text = $GIVENHASH->{$Section} if exists $GIVENHASH->{$Section}; # Determine text
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($Text); # Label
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($Text); # Resentry
						}
					# Field not locked
					else {
						# Define a Combobox
						my $ComboBox = Gtk2::ComboBox->new_text;
						# !!! This needs revision !!! The Pools should be saved in the $PCNF Personal configuration
						my @PoolList = @{$PCNF->get("USER_DEFINED_POOL_LIST")}; # Read from conffile
						foreach(@PoolList) { # Loop over temporary List
							$ComboBox->append_text($_); # Append the text
							}
						# Connect the ComboBox to the hidden field
						$ComboBox->signal_connect('changed'=>sub {my $comboBox=shift;$HASH->{RESENTRIES}->{$Section}->set_text( $ComboBox->get_active_text ) } );
						if(exists $GIVENHASH->{$Section}) { # If a text was defined
							my $Index = List::Util::first { $PoolList[$_] =~ m/$GIVENHASH->{$Section}/ } 0..$#PoolList; # Take the first pool you find that looks like the given one
							$ComboBox->set_active($Index) if defined $Index; # Set it active
							}
						$HASH->{ELEMENTS}->{$Section} = $ComboBox; # The Element is the ComboBox
						}
					}
				######################
				### MultiLine Text ###
				######################
				elsif($ElementTypes->{$Section} eq 'text-multiline') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field

					# Field should be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						my $Text=""; $Text = $GIVENHASH->{$Section} if exists $GIVENHASH->{$Section}; # Determine text
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($Text); # Label
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($Text); # Resentry
						}
					# Field not locked
					else {
						# Define a TextView
						my $TextView = Gtk2::TextView->new; # Create a new TextView
						$TextView->set_editable(TRUE); # Set editable
						$TextView->set_cursor_visible(TRUE); # Set cursor visible
						$TextView->set_wrap_mode('word'); # Set word wrap
						$TextView->set_justification('left'); # Set left justification
						$TextView->set_accepts_tab(FALSE); # No Tabs!
						$TextView->set_border_width(0); # Set border of TextView
						# Create a ScrolledWindow to hold the TextView
						my $ScrolledWindow = Gtk2::ScrolledWindow->new; # A ScrolledWindow
						$ScrolledWindow->set_shadow_type('in'); # Add the TextView to the ScrolledWindow
						$ScrolledWindow->add($TextView); # Add the TextView to the ScrolledWindow
						$ScrolledWindow->set_size_request(-1,80); # Set border of ScrolledWindow
						$ScrolledWindow->set_border_width(1); # Set border of ScrolledWindow
						$ScrolledWindow->set_policy('never','automatic'); # Never show horizontal scrollbars, but automatic vertical
	
						# Connect the value of the TextView to the hidden Entry
						$TextView->get_buffer->signal_connect('changed'=>sub{
							my $Buffer=shift; # First argument is the Buffer
							my $Text = $Buffer->get_text( $Buffer->get_start_iter, $Buffer->get_end_iter, TRUE ); # Get the Text out of the TextView
							$HASH->{RESENTRIES}->{$Section}->set_text( $Text ); # Adjust the hidden field
							});
	
						if (exists $GIVENHASH->{$Section}) {
							$TextView->get_buffer->set_text( $GIVENHASH->{$Section} ) ; # Set predefined value
							}
	
						$HASH->{ELEMENTS}->{$Section} = $ScrolledWindow; # The Element is the ScrolledWindow
						}
					}
				#########################
				### Money Entry Field ###
				#########################
				elsif($ElementTypes->{$Section} eq 'money-without-currency') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field

					# Detemine Initial given amount if even there
					my $InitialFormattedAmount=sprintf "%.2f", 0.0; # Formatted Amount for locked label
					my $InitialAmount=0; # Unformatted amount for Resentry if locked
					if ( exists $GIVENHASH->{$Section} ) { # Template was given
						if ( Scalar::Util::looks_like_number( $GIVENHASH->{$Section} ) ) { # Template looks like number
							$InitialFormattedAmount = sprintf "%.2f", $GIVENHASH->{$Section} / 100; 
							$InitialAmount=$GIVENHASH->{$Section}
							}
						else # Does not look like number
							{ $InitialFormattedAmount = sprintf "%.2f", 0.0; }
						}
					$InitialFormattedAmount =~ s/\./,/g; # Replace . with , for nice printing
	
					# Field should be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($InitialFormattedAmount ." ". $LANG->get("CURRENCY_SIGN") ); # Label
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($InitialAmount); # Resentry
						}
					# Field not locked
					else {
						my $HBox = Gtk2::HBox->new( FALSE, 0); # New HBox
						my $Entry = Gtk2::Entry->new; # The Money entry field
						$Entry->set_max_length(10); # Set Maximum length 1000000,00
						$Entry->set_alignment( 1 ); # Set Right-adjustment
						$Entry->set_size_request( 90 ); # Set size
						my $CurrencyLabel = Gtk2::Label->new; # New Label for the Currency
						$CurrencyLabel->set_markup( $LANG->get("CURRENCY_SIGN") ); # Set the currency sign
						$CurrencyLabel->set_alignment( 0, 0.5 ); # Left-justify
						$HBox->pack_start($Entry, FALSE, FALSE, 0);
						$HBox->pack_start($CurrencyLabel, TRUE, TRUE, 0);
	
						# Define what happens if changed
						$Entry->signal_connect('changed'=>sub{
							my $Entry = shift; # First argument is the Entry
							my $Text = $Entry->get_text; # Get the text
							$Text =~ s/[^0-9,.]//g; # Remove everything which is not numeric
							$Text =~ s/([,.])(?=.*?\1)//g; # Remove duplicate punctuation
							$Text =~ s/([0-9]*[,.]*[0-9]{0,2})[0-9]*[,.]*[0-9]*$/$1/g; # Remove everything in the field which is not sensible
							$Text =~ s/\n//g; # Remove newlines, if any
							$Entry->set_text($Text);
							
							# Set the hidden field
							my $ResText = $Entry->get_text;
							$ResText =~ s/,/./g; # The resulting number has to have . not ,
							if (Scalar::Util::looks_like_number($ResText)) 
								{ $ResText = $ResText * 100; } # Multiply by 100
							else
								{ $ResText = 0 } # Just use 0
							$HASH->{RESENTRIES}->{$Section}->set_text( $ResText );
							return TRUE;
							});;
	
						# Set initial text if given
						$Entry->set_text( $InitialFormattedAmount ); # Set the value to show
	
						$HASH->{ELEMENTS}->{$Section} = $HBox; # The HBox is the Element
						}
					}
				######################
				### Tags Selection ###
				######################
				elsif($ElementTypes->{$Section} eq 'tags-selection') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field

					# Field should be locked?
					if ( exists $PREFS->{LOCK}->{$Section} ) { 
						my $Text=""; $Text = $GIVENHASH->{$Section} if exists $GIVENHASH->{$Section}; # Determine text
						$HASH->{ELEMENTS}->{$Section}=Gtk2::Label->new($Text); # Label
						$HASH->{ELEMENTS}->{$Section}->set_alignment(0,0.5); # Left-align
						$HASH->{RESENTRIES}->{$Section}->set_text($Text); # Resentry
						}
					# Field not locked
					else {
						# Define a Tags selection widget
						my $tmp = $PCNF->get("USER_DEFINED_TAGS_LIST"); # Try to read user-defined tags
						my @USERTAGS = ref $tmp eq "ARRAY" ? @$tmp : (); # Format it to list

						my $ComboBox = Gtk2::ComboBox->new_text; # A text combobox
						$ComboBox->set_wrap_width(3); # Set wrap width

						foreach(@USERTAGS) { # Loop over temporary List
							$ComboBox->append_text($_); # Append the text
							}
						# Connect the ComboBox to the hidden field
						$ComboBox->signal_connect('changed'=>sub {my $comboBox=shift;$HASH->{RESENTRIES}->{$Section}->set_text( $ComboBox->get_active_text ) } );
						if(exists $GIVENHASH->{$Section}) { # If a text was defined
							my $Index = List::Util::first { $USERTAGS[$_] =~ m/$GIVENHASH->{$Section}/ } 0..$#USERTAGS; # Take the first pool you find that looks like the given one
							$ComboBox->set_active($Index) if defined $Index; # Set it active
							}
			
						# Use a ComboBox
						$HASH->{ELEMENTS}->{$Section} = $ComboBox;
						}
					}
				##############
				### Hidden ###
				##############
				elsif($ElementTypes->{$Section} eq 'hidden') {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field
					$HASH->{RESENTRIES}->{$Section}->set_text( $GIVENHASH->{$Section} ) if exists $GIVENHASH->{$Section}; 
					$ShowInTable = FALSE; # Don't try to show it in the Table
					}
				#######################
				### Standard Widget ###
				#######################
				else {
					$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field
					# If nothing matches, just defina a textfield
					$HASH->{ELEMENTS}->{$Section} = Gtk2::Entry->new;
					$HASH->{ELEMENTS}->{$Section}->signal_connect('changed'=>sub{ 
						my $Entry = shift; # Argument is Entry
						my $Text = $Entry->get_text; # Get text
						$Text =~ s/\n//g; # Remove newlines, if any
						$HASH->{RESENTRIES}->{$Section}->set_text( $Text );
						});;
					$HASH->{ELEMENTS}->{$Section}->set_text( $GIVENHASH->{$Section} ) if exists $GIVENHASH->{$Section};
					}
				}
			#################################################
			### Type was not defined, assume hidden field ###
			#################################################
			else {
				$HASH->{RESENTRIES}->{$Section} = Gtk2::Entry->new; # Hidden Entry Field
				$HASH->{RESENTRIES}->{$Section}->set_text( $GIVENHASH->{$Section} ) if exists $GIVENHASH->{$Section};
				$ShowInTable = FALSE; # Don't try to show it in the Table
				}


			####################################################
			### Put the Label and the Element into the Table ###
			####################################################
			if($ShowInTable) { # Only add if it's no hidden field
				# Attach the Label to the left side of the Table
				$HASH->{TABLE}->attach( $HASH->{LABELS}->{$Section}  , 0, 1, $count, $count+1 , 'fill', 'fill', 1, 5 );
				# Attach the element to the right side of the Table
				$HASH->{TABLE}->attach_defaults( $HASH->{ELEMENTS}->{$Section}, 1, 2, $count, $count+1);
				}

			$count++;
			}

		$HASH->{TABLE}->set_border_width(5); # Set the border of the Table
		$HASH->{TABLE}->show_all; # show everything in the Table


		return $HASH; # Return the filled hash
		};


	my @ALLTABLEHASHES; # Variable to hold all TableHashes that are currently in the NoteBook



	# This variable has to be defined here, because of the anonymous subroutines in use
	# The sub $AppendTableToNoteBook needs to know about this variable
	$DIALOG{DialogNoteBookAddPageLabel}=Gtk2::Label->new; 


	##############################################
	### Sub to remove a page from the NoteBook ###
	##############################################
	my $RemoveTableFromNoteBook = sub {
		my ($button, $TableHash)=@_; # Argument is the TableHash
		my $notebook = $DIALOG{DialogNoteBook};
		$notebook->remove_page( $notebook->page_num( $TableHash->{TABLE} ) );  # Find out tabnumber and close it

		# Remove given TableHash from the variable @ALLTABLEHASHES
		@ALLTABLEHASHES = grep { $_ != $TableHash } @ALLTABLEHASHES;
		#print "###############\nREMOVED\n################\n",Dumper \@ALLTABLEHASHES;
		};


	#########################################
	### Sub to add a page to the NoteBook ###
	#########################################
	my $AppendTableToNoteBook = sub {
		my $TableHash = shift; # Expect the first argument to be a TableHash created with &$CreateTableHash(HASH)
		$TableHash = &$CreateTableHash( $PREFS->{TEMPLATE} ) unless ref $TableHash eq 'HASH'; # Use Empty Table if no Hash was given
		
		# Bind the Tab Title to the specified field
		if (List::Util::first {$_ eq $TabTitleField} @{$ElementOrder}) { # If the specified field really exists
	
			###################################
			### Sub to Adjust the Tab Title ###
			###################################
			my $changetabtitle = sub {
				my $NewText=$_[0]->get_text; # The new text is the content of the Entry-Widget that starts this sub
				my $Max = $CONF->get("EDITDIALOG_NOTEBOOK_TAB_TITLE_Max_LENGTH"); # Maximum number of letters in tab title
				$Max = 20 unless Scalar::Util::looks_like_number($Max);
				$NewText = eval{substr $NewText, 0, $Max} . "..." if length $NewText > $Max;
				$NewText = $LANG->get("EDITDIALOG_NOTEBOOK_TAB_TEXT_IF_NO_COLUMN_FIELD") if length $NewText == 0;
				$TableHash->{TAB}->{Label}->set_markup("<b>$NewText</b>"); # Set the new text in bold
				$TableHash->{TAB}->{MenuLabel}->set_markup("<b>$NewText</b>"); # Set the new text in bold
				};

			# Connect the sub to the Field
			$TableHash->{RESENTRIES}->{$TabTitleField}->signal_connect('changed'=>$changetabtitle);
			}

		# Connect the close button to the tab close sub
		$TableHash->{TAB}->{Button}->signal_connect('clicked' => $RemoveTableFromNoteBook, $TableHash );

		# Add a new Tab Page to the Notebook
		$DIALOG{DialogNoteBook}->append_page( $TableHash->{TABLE} , $TableHash->{TAB}->{HBox});
		$DIALOG{DialogNoteBook}->set_menu_label( $TableHash->{TABLE} , $TableHash->{TAB}->{MenuLabel});
		$DIALOG{DialogNoteBook}->set_tab_reorderable( $TableHash->{TABLE}, TRUE );

		# Add the TableHash to the list @ALLTABLEHASHES
		push @ALLTABLEHASHES, $TableHash;
		#print "###############\nADDED\n################\n",Dumper \@ALLTABLEHASHES;

		# Focus the newly created Tab
		$DIALOG{DialogNoteBook}->set_current_page( $DIALOG{DialogNoteBook}->page_num( $TableHash->{TABLE} ) );

		# Reorder the Add-Tab at the end
		$DIALOG{DialogNoteBook}->reorder_child( $DIALOG{DialogNoteBookAddPageLabel}, $DIALOG{DialogNoteBook}->get_n_pages - 1  );
		};


	############################################
	### Now fill the Notebook up with tables ###
	############################################
   foreach my $AktDataHash ( @GIVENDATAHASHES ) {
		my $TableHash = &$CreateTableHash( $AktDataHash ); # Create a table with the defined sub

		&$AppendTableToNoteBook( $TableHash ); # Call the sub to append the TableHash to the Notebook
		}



	#####################################
	### Add a Button to add a new Tab ###
	#####################################
	$DIALOG{DialogNoteBookAddPageButton} = Gtk2::Button->new;
	$DIALOG{DialogNoteBookAddPageButton}->set_image( Gtk2::Image->new_from_stock( eval { $CONF->get("EDITDIALOG_NOTEBOOK_ADD_STOCK_ICON") or 'gtk-add' } ,'menu') );
	$DIALOG{DialogNoteBookAddPageButton}->set_relief('none');
	# If clicked, Append an empty Page
	$DIALOG{DialogNoteBookAddPageButton}->signal_connect('clicked' => $AppendTableToNoteBook, &$CreateTableHash({}));
	$DIALOG{DialogNoteBookAddPageButton}->show;

	$DIALOG{DialogNoteBookAddPageLabel}->set_markup( $LANG->get('EDITDIALOG_NOTEBOOK_ADD_TAB_TEXT') ); 
	$DIALOG{DialogNoteBookAddPageLabel}->show; 
	$DIALOG{DialogNoteBook}->append_page( $DIALOG{DialogNoteBookAddPageLabel} , $DIALOG{DialogNoteBookAddPageButton} );
	$DIALOG{DialogNoteBook}->set_menu_label( $DIALOG{DialogNoteBookAddPageLabel} , Gtk2::HBox->new );
	$DIALOG{DialogNoteBook}->set_tab_reorderable( $DIALOG{DialogNoteBookAddPageLabel}, FALSE );


	$DIALOG{DialogNoteBook}->show; # Show the NoteBook

	# Put the NoteBook into the vbox
	$DIALOG{DialogVBox}->pack_start($DIALOG{DialogNoteBook}, FALSE, FALSE, 0);

	# Run the dialog and save the action in the Variable $RES
	my $RES = $DIALOG{Dialog}->run; # Run the dialog
	$DIALOG{Dialog}->destroy; # Destroy it, when closed

	########################################
	### Return the resulting hash or not ###
	########################################
	if($RES eq 'yes') { # User clicked 'save'
		my @RETURN; # List to return

		# Loop over all TableHashs and put them into a hash
		foreach my $TableHash ( @ALLTABLEHASHES ) {
			my $Hash = {};
			foreach my $Section (keys $TableHash->{RESENTRIES}) {
				$Hash->{$Section} = $TableHash->{RESENTRIES}->{$Section}->get_text;
				}
			push @RETURN, $Hash;
			}
		print Dumper \@RETURN;
		return @RETURN;
		}
	else { # User didn't click 'save'
		print Dumper [];
		return (); # Just return empty list
		}
	}

#################################
### Subs to control behaviour ###
#################################

#########################################
### Show Information in the StatusBar ###
#########################################
sub showinfo {
	my ($widget, $info) = @_; 	# Read the parameters
	$info = "" unless $info;

	# Update the Text in the StatusBar
	$GTK{MainStatusBarLeft}->set_text($info);
	}

# Show Standard Information in the StatusBar
sub stdinfo {
	my ($widget, $data) = @_; 	# Read the parameters
	# Update the Text in the StatusBar
	$GTK{MainStatusBarLeft}->set_text( $LANG->get("STATUSBAR_STANDARD") );
	}


############################################################################################
### Sub to update the status bar information like the number of datasets in the database ###
############################################################################################
# Sensibly call this function after any change in the data
sub update_status_bar_information_right {
	my $anzrows = $DATA->{R}->get("NOCgetnumberofdatasets()");
	my $anzrowsstring;
	if    ( $anzrows == 0 ) { $anzrowsstring = $LANG->get("WORD_NO_DATASET") }
	elsif ( $anzrows == 1 ) { $anzrowsstring = $anzrows . " " . $LANG->get("WORD_DATASET") }
	else                    { $anzrowsstring = $anzrows . " " . $LANG->get("WORD_DATASETS") }

	my $anzchanges = $DATA->{R}->get("NOCgetnumberofchanges()");
	my $anzchangesstring;
	if    ( $anzchanges == 0 ) { $anzchangesstring = $LANG->get("WORD_NO_CHANGES") }
	elsif ( $anzchanges == 1 ) { $anzchangesstring = $anzchanges . " " . $LANG->get("WORD_CHANGE") }
	else                       { $anzchangesstring = $anzchanges . " " . $LANG->get("WORD_CHANGES") }

	$GTK{MainStatusBarRight}->set_text( $anzrowsstring . ", " . $anzchangesstring );  # Show text in right side of StatusBar


	# Create a new TreeView
	# TODO: Don't create a new TreeView, but update the old!
	$DATA->{R}->run(qq`NOCselectall()`);
	#print "\n\nNOCDATA:\n",$DATA->{R}->run(qq`NOCDATA`),"\n\n";
	$GTK{MainTreeView}->destroy;
	$GTK{MainTreeView}=&TreeViewFromData({},$DATA->NOCgetselectedrows);
	$GTK{MainTable}->attach_defaults($GTK{MainTreeView}, 0, 1, 0, 1);
	
	}


##################################################################
### Show a popup window with the markup text given as argument ###
##################################################################
sub show_popup_window_with_text {
	my $text = shift; # First argument is string to be shown

	# Dialog erstellen
	my $dialog = Gtk2::Dialog->new(
		$LANG->get('POPUP_WINDOW_TITLE_STANDARD'), # Title
		$GTK{Window}, # Main Window is parent
		[qw/modal destroy-with-parent/], # Flags
		'OK' => 'yes', # Buttons
		);
	
	my $vbox = $dialog->vbox; # Get the VBox to pack the text into
	my $textlabel = Gtk2::Label->new; # Text
	$textlabel->set_markup( $text ); # Set the markup-Text

	$vbox->pack_start( $textlabel, FALSE, FALSE, 10); # Put the label into the Window-VBox
	$vbox->show_all; # Show everything in the vbox

	$dialog->run; # Show the window
	$dialog->destroy; # Destroy it, when closed
	}


#################################################
### Show Information Window with NomCash-Logo ###
#################################################
sub show_info_window {
	my ($widget, $data) = @_;
	my $text = $LANG->get("INFORMATION_WINDOW_TEXT"); # Text
		
	# Dialog erstellen
	my $dialog = Gtk2::Dialog->new(
		$LANG->get('INFORMATION_WINDOW_TITLE'), # Title
		$GTK{Window}, # Main Window is parent
		[qw/modal destroy-with-parent/], # Flags
		'OK' => 'yes', # Buttons
		);
	
	my $vbox = $dialog->vbox; # Get the VBox to pack the text into
	my $textlabel = Gtk2::Label->new; # Text
	$textlabel->set_markup( $LANG->get('INFORMATION_WINDOW_TEXT') ); # Set the markup-Text

	my $hbox = Gtk2::HBox->new( FALSE, 0 ); # HBox for Logo and Text

	# Try to use an image
	my $imagepath = $NomCash::Info::SANDBOX . $CONF->get("GTK_NOMCASH_INFO_LOGO_PATH");
	if( -e -r $imagepath ) { # Does the image file exist?
		my $image = Gtk2::Image->new_from_file( $imagepath ); # If yes, load it
		$hbox->pack_start( $image, FALSE, FALSE, 0 ); # and put it into the hbox
		}

	$hbox->pack_start( $textlabel, FALSE, FALSE, 0 ); # Put the Text into the HBox
	$hbox->show_all; # Show everything in the HBox
	$vbox->pack_start( $hbox, FALSE, FALSE, 0); # Put the HBox into the Window-VBox

	$dialog->run; # Show the window
	$dialog->destroy; # Destroy it, when closed
	}

# Delete the given hashes from database
sub delete_hashes_from_database {
	my @HASHES = @_; # Given hashes
	$DATA->NOCdelete(@HASHES); # Delete
	&update_status_bar_information_right; # Update View
	}

# Save the work
# Just another wrapper around the R-functions to save the current state
# Also save stats and configuration
sub save_current_state {
	my ($widget, $data) = @_;  # Parameters
	$DATA->NOCwriteout; # Let R writeout its contents

	# Save stats
	$STAT->writeout;

	# Save configuration
	$PCNF->writeout;

	&update_status_bar_information_right; # Update status bar
	}



# Quit NomCash, but first ask the user to confirm and whether he wants to save his work
sub quit_nomcash {

	# Check whether there are any changes
	if( $DATA->{R}->get("NOCgetnumberofchanges()") > 0 ) {

		# Create a dialog to ask the user if he wants to save or not
		my $dialog = Gtk2::Dialog->new(
			$LANG->get("SAVE_ON_QUIT_DIALOG_TITLE"), # Title
			$GTK{Window}, # Main Window is parent
			[qw/modal destroy-with-parent/], # Flags
			$LANG->get("SAVE_ON_QUIT_DIALOG_BUTTON_SAVE_AND_QUIT_TEXT") => 'yes',
			$LANG->get("SAVE_ON_QUIT_DIALOG_BUTTON_DONT_SAVE_BUT_QUIT_TEXT") => 'no',
			$LANG->get("SAVE_ON_QUIT_DIALOG_BUTTON_DONT_QUIT_TEXT") => 'cancel'
			);
		my $vbox = $dialog->vbox; # Get the VBox to pack the text into
		my $hbox = Gtk2::HBox->new( FALSE, 0 ); # An HBox to hold an icon and the text
		$hbox->pack_start(Gtk2::Image->new_from_stock('gtk-save','dialog'), TRUE, FALSE, 0); # Add an Icon
		$hbox->pack_start(Gtk2::Label->new( $LANG->get("SAVE_ON_QUIT_DIALOG_TEXT") ), TRUE, FALSE, 0); # Add text
		$hbox->show_all; # Show everything in the HBox
		$vbox->pack_start($hbox, FALSE, FALSE,10); # Put the HBox into the Vbox
	
		$dialog->signal_connect(response => \&choicesub); # React to user's choice
	
		$dialog->run; # Show the window and save the user's decision in the variable $decision (either 'yes', 'no' or 'cancel')
		$dialog->destroy; # Destroy it, when closed
		}

	# There are no changes, so nothing needs to be saved!
	else {
		&choicesub(undef,'no'); # Pretend as if the user clicked 'no' in the dialog
		}

	# Sub to react to the users choice
	sub choicesub {
		my ($widget, $decision) = @_; # Read parameters, $choice is the button clicked
		# Now react to the user's choice
		if($decision eq 'yes') { # User wants to save and quit
			# Letzte Startzeit speichern
			$STAT->set("LAST_GTK_START_FORMAT",$NomCash::Info::DATE); # Letztes Startdatum setzen
			$STAT->set("LAST_GTK_START_STAMP", sprintf("%d", $NomCash::Info::TIME)); # Letztes Startdatum setzen	
	
			&save_current_state; # Save the Standard Database,the personal configuration and the stats  to the respective sourcefile

			Gtk2->main_quit; # Gtk2 beenden, Loop verlassen
			exit 0; # Perl beenden
			}
		elsif($decision eq 'no') { # User does not want to save, but to quit
			# Letzte Startzeit speichern
			$STAT->set("LAST_GTK_START_FORMAT",$NomCash::Info::DATE); # Letztes Startdatum setzen
			$STAT->set("LAST_GTK_START_STAMP", sprintf("%d", $NomCash::Info::TIME)); # Letztes Startdatum setzen	
			$STAT->writeout;
			# Just Quit without saving
			Gtk2->main_quit; # Gtk2 beenden, Loop verlassen
			exit 0; # Perl beenden
			}
		elsif($decision eq 'cancel'){ # User doesn't want to quit
			# Don't do anything!
			}
		}
	
	return TRUE; # Tell the event, that is has been taken care of and thus prevent the parent window from being closed
	} 


# Erfolgreich beenden


1;
