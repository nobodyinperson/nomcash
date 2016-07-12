# #!/usr/bin/Rscript
# Functions to get information from the database

##### Basic information from database #####
# Return the number of recorded datasets in the NOCDATA variable
NOCgetnumberofdatasets = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Find out the amount of data sets
	anz = length(row.names(NOCDATA))
	
	# Return it
	return(anz)
	}


# Get the number of recorded changes
NOCgetnumberofchanges = function() {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Coerce NOCCHANGES variable into a numeric value
	NOCCHANGES <<- as.numeric(NOCCHANGES)
	
	# Return NOCCHANGES
	return(NOCCHANGES)
	}


# Get the header of the data variable NOCDATA
NOCgetdatacolnames = function() {
	NOCinitmainvariables() # Make sure main variables exist

	# Return the colnames
	return(colnames(NOCDATA))
	}


##### Get selected rows #####
# Get the defined rows out of the database
# just as one list
# this is the way the Perl Module Statistics::R can 
# handle the data
NOCgetrowsasvector = function(selection) {
	NOCinitmainvariables() # Make sure main variables exist
	
	# Only take sensible rows
	selection = as.numeric(intersect(row.names(NOCDATA), selection))

	# Get the selected rows
	rows = as.vector(t(NOCDATA[selection,]))
	
	if(length(rows)==0) { # If there are no lines, then return FALSE
		return(FALSE)
		}
	
	# Return lines
	return(rows)
	}


# Get the actual selection
NOCgetselection = function() {
	NOCinitmainvariables() # Make sure main variables exist
	return(as.vector(NOCSELECTION)) # Return it
	}


# Return the selected rows as vector
NOCgetselectedrowsasvector = function() {
	# Return selected rows
	return(NOCgetrowsasvector(NOCSELECTION))
	}