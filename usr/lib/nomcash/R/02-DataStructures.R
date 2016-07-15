#!/usr/bin/Rscript
# Basic R functions for the NomCash Application

##### Function to create and set the main variables #####
# Call this function at the start of any function that needs these variables
NOCinitmainvariables = function() {
	# Create main variables
	if(! exists("NOCSELECTION") ) { NOCSELECTION <<- NULL }
	if(! exists("NOCDATA") )      { NOCDATA <<- as.data.frame(NULL) }
	if(! exists("NOCCHANGES") )   { NOCCHANGES <<- 0 }

	# Create temporary variables
	if(! exists("NOCSAVEENTRYCOLTEMP") )  { NOCSAVEENTRYCOLTEMP <<- NULL }
	if(! exists("NOCSAVEENTRYVALTEMP") )  { NOCSAVEENTRYVALTEMP <<- NULL }
	if(! exists("NOCSELECTIONTEMP") )    { NOCSELECTIONTEMP <<- NULL }
	}

#### Function to set the NOCDATA variable ####
# The NOCDATA variable is only set again, if the given value is not identical to the current NOCDATA variable and if the given value is a data.frame
# ARGUMENTS:
# - NOCDATAnewvalue: new value for NOCDATA, should be a data.frame, unless the function will ignore it
# - ChangeRegister: Should the (really) changed value be registered as a change?
# - PostProcessing: Should the NOCDATA variable be postprocessed like redefining the rownames or filling and fixing of the ID column? May be set to FALSE to avoid infinite loops
NOCsetNOCDATA = function(NOCDATAnewvalue=as.data.frame(NULL),ChangeRegister=TRUE,PostProcessing=TRUE) { 
	NOCinitmainvariables() # Create main variables
	
	# If a real change was made, register a change, if desired
	if(! identical(NOCDATA, NOCDATAnewvalue) ) { # Is given value a change?
		if(is.data.frame(NOCDATAnewvalue)) { # Only do something if given value is data.frame
			NOCDATA <<- NOCDATAnewvalue # Set NOCDATA if given value is data.frame
			if(ChangeRegister) NOCchangeregister() # Register a change is specified
			
			# Update row names and IDs if desired
			if(PostProcessing) {
				NOCredefinerownames() # Redefine the row names
				NOCfillandfixIDs() # Fill IDs
				}
			}
		else { # Given value is no data.frame!
			warn("NomCash-R: You passed a non-data-frame argument to function NOCsetNOCDATA(). Nothing will be changed!\n")
			}
		}
	}

NOCgetmaxID = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	if(is.null(NOCDATA$ID)) return(0) # Return 0 if non existant column or no rows
	if(all(is.na(NOCDATA$ID))) return(0) # Return 0 if all is NA
	MaxID = max(NOCDATA$ID,na.rm=T) # Get maximum
	if(!is.finite(MaxID)) MaxID = 0 # If MaxID is bogus, then use 0
	return(MaxID)
}

##### Functions to record some stats #####

# Increase the global variable NOCCHANGES by one
# Call this function every time you change anything in the NOCDATA variable
NOCchangeregister = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Coerce NOCCHANGES variable into a numeric value
	NOCCHANGES <<- as.numeric(NOCCHANGES)
	
	# Increase NOCCHANGES variable by one
	NOCCHANGES <<- NOCCHANGES + 1
}


# Reset the NOCCHANGES variable to 0
NOCchangereset = function() {
	# Reset NOCCHANGES variable to 0
	NOCCHANGES <<- 0
}


##### Functions to control database #####

# Function to redefine the datas rownames (e.g. after deleting lines)
NOCredefinerownames = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	anz = NOCgetnumberofdatasets() # Determine amount of rows
	
	# Set new row names if there are any rows
	if(anz > 0)	row.names(NOCDATA) <<- seq(from=1,to=anz,by=1)
	}

# Function to fill the ID column up
# FYI: This function MUST be called after every change in the database!
NOCfillandfixIDs = function() {
	NOCinitmainvariables() # Make sure main variables exist
	if(is.null(NOCDATA$ID)) NOCDATA$ID = NA # Set ID column if non existant
	# Remove double IDs
	NOCDATA$ID[duplicated(NOCDATA$ID)] <<- NA

	# Remove everything that is non-integer
	NOCDATA$ID[!is.numeric(NOCDATA$ID)] <<- NA
		
	# Now fill it up again
	# First number of missing ID
	IndexNoIDs = which(is.na(NOCDATA$ID))
	AnzNoIDs = length(IndexNoIDs)
	if(AnzNoIDs > 0) { # Only change something if there are missing IDs
		# Determine maximum ID
		MaxID = NOCgetmaxID()
			
		# Set undefined elements
		NOCDATA$ID[IndexNoIDs] <<- seq(from=MaxID+1,by=1,length=AnzNoIDs)
		}
	}

# Function to select given Dataset
NOCselect = function(selection, append=FALSE) {
	NOCinitmainvariables() # Make sure main variables exist

	# Only take those numbers into the selection that are in the data frame
	selection = as.numeric(intersect(row.names(NOCDATA), selection))

 	# Put the remaining row numbers into the global NOCSELECTION variable
	# Create variable NOCSELECTION if it does not exist
	if(! exists("NOCSELECTION") ) { NOCSELECTION <<- NULL }
	
	if(append==TRUE) { # Append to global selection
		NOCSELECTION <<- union(NOCSELECTION, selection)
		}
	else { # replace global selection
		NOCSELECTION <<- selection
		}
	
	return(selection)
}


# Function to select everything in the Database
NOCselectall = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Get all rownames
	selection = as.numeric(rownames(NOCDATA))
	
	# Put everything into the selection variable
	NOCSELECTION <<- selection
	return(selection)
}

# Function to append to global selection
# Just a wrapper around the NOCselect function
NOCselectappend = function(selection) {
	NOCselect(selection,append=TRUE)
	}

# Function to empty the NOCSELECTION variable
NOCclearselection = function() {
	NOCSELECTION <<- NULL
	}


# Function to delete given rows from data variable
NOCdelete = function(selection) {
	NOCinitmainvariables() # Make sure main variables exist
	if(length(selection)==0) { return(FALSE) }
	# Only take those numbers into the selection that are in the data frame
	selection = as.numeric(intersect(row.names(NOCDATA), selection))
	
	# Remove the selected rows from data variable
	NOCDATA <<- NOCDATA[-selection,]

	NOCchangeregister() # Notice a change
	
	# Redefine the rownames to avoid strange things
	NOCredefinerownames()
	
	# Fix IDs
	NOCfillandfixIDs()
	}

# Function to delete rows by IDs
# But dont register a change
NOCdeletebyIDsWithoutChange = function(IDs,changeregister=FALSE) {
	NOCinitmainvariables() # Make sure main variables exist
	if(length(IDs)==0) { return() }
	IDs = as.vector(IDs) # Convert to vector
	IDs = as.integer(IDs[!is.na(IDs)]) # Remove NA
	# Only take those numbers into the selection that are in the data frame
	
	# Remove rows
	for (ID in IDs) {	
		if(length(row.names(NOCDATA[ NOCDATA$ID == ID ,])) > 0)
			NOCDATA <<- NOCDATA[ NOCDATA$ID != ID ,] # Remove rows
			# Register a change
			if(changeregister) NOCchangeregister();
		}
	
	NOCredefinerownames(); # Redefine row names
	
	}

# Function to delete rows by IDs 
# AND register a change
NOCdeletebyIDs = function(IDs) {
	NOCdeletebyIDsWithoutChange(IDs,changeregister=TRUE) # Delete rows
	}

# Function to delete all with NOCselect() selected rows from data variable NOCDATA
# Wrapper around NOCdelete()-function
NOCselectiondelete = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Call NOCdelete()-function
	NOCdelete(NOCSELECTION)
	
	# Clear the selection variable
	NOCclearselection()
	}


##### Add a new dataset #####

# Add the dataframe "entry" to the global variable NOCDATA
NOCsaveentry = function(entry) {
	NOCinitmainvariables() # Make sure main variables exist
	# Coerce argument to data frame
	entry = as.data.frame(entry)
	
	# Check if ID is already in NOCDATA
	NOCdeletebyIDs(entry$ID)
		
	# Add to global variable NOCDATA
	NOCDATA <<- concatenate.data.frames(dataframe1=NOCDATA, dataframe2=entry)
		
	# Tidy up
	NOCredefinerownames()
	NOCfillandfixIDs()
	NOCclearselection()
	NOCclearnewentrytemp()
		
	# Register a change
	NOCchangeregister()
	}


# Clear the temporary variables for newentry
NOCclearnewentrytemp = function() {
	NOCSAVEENTRYCOLTEMP <<- NULL
	NOCSAVEENTRYVALTEMP <<- NULL
}


# Alternatively fill the global temporary variables NOCSAVEENTRYVALTEMP and NOCSAVEENTRYCOLTEMP:
# NOCSAVEENTRYCOLTEMP: vector with colnames
# NOCSAVEENTRYVALTEMP: vector with the entry itself, of course in a sensible order according to NOCSAVEENTRYCOLTEMP
# Both have to have the same length! If not, the longer one will be cut off anyway...
# Then call this function to add this entry to the global variable NOCDATA
NOCsaveentryfromtemp = function() {
	NOCinitmainvariables() # Make sure main variables exist
	# First prepare the temporary variables for use
	columnames = as.vector(NOCSAVEENTRYCOLTEMP)
	entryvalue = as.vector(NOCSAVEENTRYVALTEMP)
	
	# Cut off what is too much
	minlength = min(length(columnames),length(entryvalue))
	columnames = columnames[1:minlength]
	entryvalue = entryvalue[1:minlength]
	
	# Create an empty data frame from colnames
	newentrydataframe = data.frame.empty.with.colnames(columnames)
	
	# Add the entry values to the data frame
	newentrydataframe[1,] = entryvalue

	# Now append it to the NOCDATA variable
	NOCsaveentry( newentrydataframe )
	
	# Clear the temporary variables
	NOCclearnewentrytemp()
	}