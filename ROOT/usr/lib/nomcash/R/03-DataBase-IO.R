#!/usr/bin/Rscript
##### Functions to read/write to/from source files #####

# Read data file
# Takes the name of the file as argument
# Checks almost everything, that could let the read.table()-function die:
# ---> file not existant, return empty dataframe
# ---> file has no header, return empty dataframe
# ---> file has less than 2 lines, return empty dataframe
# ---> file doesn't end in a newline - in this case, append a newline to the file
# If header and content do not match, it fails...
# Couldn't figure out how to check this easily...
# Return the dataframe read from infile
NOCread = function(infile) {
	if(! file.exists(infile) | file.info(infile)$size == 0 ) { # Don't read anything if file doesn't exist
		#cat("File does not exist or is empty...\n")
		return(as.data.frame(NULL)) # Just return an empty data frame
		}
	
	# Read whole file temporarily into a character variable
	# Yeees, I know that this is stupid, but I need to prevent read.table() from dying
	# horribly when the file doesn't have enough lines or doesn't end in a newline...
	filestring = readChar(infile, file.info(infile)$size) # Read whole file
	
	# Is the file full enough?
	if( length(strsplit(filestring,split="\n")[[1]]) < 2) { # If the file contains less than two lines (minimum: Header and one line!)
		#cat("File has less than 2 lines\n")
		return(as.data.frame(NULL)) # Just return an empty data frame  	
	}
	
	# Does the file end with a newline character?
	if(! substr(filestring, start=nchar(filestring), stop=nchar(filestring)+1) == "\n") {
		#cat("File doesn't end in newline...\n")
		
		# Add a newline to the end and then try to read
		filestringwithnewline = as.character(paste(filestring,"\n",sep=""))
		# Now writeout new filestring to file
		writeChar(object=filestringwithnewline,con=infile,nchars=nchar(filestringwithnewline),eos=NULL)
		
		#return(as.data.frame(NULL)) # Just return an empty data frame  	
	}
	
	# If everything above doesn't cause any problems, eventually read the file into a data frame!	
	read.table(file=infile, # Inputfile
						 sep="\t", # Data ist separated by TABS
						 comment.char="#", # Comment character is a hashtag
						 na.strings="<NA>", # NA-Strings
						 header=TRUE) # Take the first line as header
}

# Read from infile and replace global variable NOCDATA
# Do NOT register this action with NOCchangeregister(), but reset the changes
NOCreadinit = function(infile) {
	NOCinitmainvariables() # Make sure main variables exist
	NOCsetNOCDATA( # Set the NOCDATA variable
		NOCread(infile), # Put the new dataframe into it
		ChangeRegister=FALSE, # Do NOT Register this as a change
		PostProcessing=TRUE # Do the PostProcessing
		) # Replace with read data
	NOCclearselection() # Old selection has to be deleted to prevent strange things
	NOCchangereset() # Reset changes
	}

# Read Data from infile and append it to variable NOCDATA
# If collapse="COLNAME", delete all new lines that are equal to older ones in column "COLNAME"
NOCreadappend = function(infile) {
	NOCinitmainvariables() # Make sure main variables exist
	if(!file.exists(infile)) {return(FALSE)}
	TEMPread = NOCread(infile) # Try to read from infile
	if(! is.data.frame(TEMPread)) { return(FALSE) } # If infile is not readable, stop
	
	else { # Global Variable NOCDATA exists already
		# Now delete the lines from NOCDATA that have IDs that are also in TEMPread
		EqualIDs = as.integer(intersect(NOCDATA$ID,TEMPread$ID)) # Get equal lines
		NOCdeletebyIDs(EqualIDs) # Delete equal lines
		NOCsetNOCDATA( # Set the NOCDATA variable
			concatenate.data.frames(NOCDATA, TEMPread), # Put the appended dataframe into it
			ChangeRegister=TRUE, # Register this as a change
			PostProcessing=TRUE # Do the PostProcessing
			) # Append read data
	}
}


# Read from infile and replace global variable NOCDATA
NOCreadreplace = function(infile) {
	NOCinitmainvariables() # Make sure main variables exist
	NOCsetNOCDATA( # Set the NOCDATA variable
		NOCread(infile), # Put the new dataframe into it
		ChangeRegister=TRUE, # Register this as a change
		PostProcessing=TRUE # Do the PostProcessing
	) # Replace with read data
	NOCclearselection() # Old selection has to be deleted to prevent strange things
	}





# Clear the NOCDATA variable to an empty data frame
NOCcleardata = function() {
	NOCinitmainvariables() # Make sure main variables exist
	# Clear the NOCDATA variable
	NOCsetNOCDATA(as.data.frame(NULL), # Use an empty data frame
								ChangeRegister=TRUE, # Register this as a change
								PostProcessing=FALSE) # Do not post-process, because nothing is there anyway
	NOCclearselection() # Old selection has to be deleted to prevent strange things0
}


# Writeout to file
NOCwriteoutbase = function(data, outfile) {
	write.table(data, # Data to be written
							file=outfile, # File to be written to
							sep="\t", # Separated by TABS
							quote=FALSE, # No quotes for strings
							na="<NA>", # NA-Strings
							row.names=FALSE) # No row numeration
}

# Writeout NOCDATA to file
NOCDATAwriteout = function(outfile) {
	NOCinitmainvariables() # Make sure main variables exist
	NOCwriteoutbase(data=NOCDATA,outfile=outfile) # Writeout
	NOCchangereset() # Reset changes
}
