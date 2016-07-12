#!/usr/bin/Rscript
##### Basic function to get around some R issues #####

# Function to concatenate data frames while inserting NAs into unknown columns
# If collapse="COLNAME", then overwrite lines of dataframe1 with lines of dataframe2 which have an equal value in COLNAME
# CAUTION: The collapse argument is still a little buggy. It fails for some reason, if one dataframe ends up empty after filtering out collapsing lines... 
concatenate.data.frames = function(dataframe1, dataframe2, fill=NA, collapse=FALSE) {
	# If one of dataframe1 or dataframe2 is empty, then only return the filled one
	#print(length(dataframe1),length(dataframe2))
	if(length(as.data.frame(dataframe1)) == 0) { return(dataframe2) }
	if(length(as.data.frame(dataframe2)) == 0) { return(dataframe1) }
	
	
	# First, define function to fill gaps with NAs
	sbind.fill = function(dataframe, unequalcols){ # Fill NAs into unequalcols
		for(col in unequalcols) # Iterate over all unequal columns
			dataframe[[col]] = fill # Create column with name of "col"-content and fill it with "fill"-variable
		dataframe # Return dataframe variable
	}
	
	
	# Now delete lines if collapse is not FALSE
	if(is.character(collapse)) { # Only if collapse is a character
		if(collapse %in% colnames(dataframe1)) { # The given collapse-Column exists in first dataframe (the older one)
			# Now delete the lines of dataframe2 if collapse is equal
			equalcollapsekeys = intersect(dataframe1[,collapse], dataframe2[,collapse]) # equal values in collapse-field
			equalcollapsekeysindex = which(dataframe2[,collapse] %in% equalcollapsekeys) # indices, where collapse-fields are equal
			# Delete lines
			dataframe2 = dataframe2[-equalcollapsekeysindex,]
		}
	}
	
	# Now fill the gaps with NAs
	dataframe1 = sbind.fill(dataframe1, setdiff(names(dataframe2),names(dataframe1)))
	dataframe2 = sbind.fill(dataframe2, setdiff(names(dataframe1),names(dataframe2)))
	
	rbind(dataframe1, dataframe2) # Concatenate the two dataframes
}




# Function to return a data.frame without any rows but with colnames specified
# !! Caution: For some reason the resulting dataframe columnames end up prefixed with an "X" if they initially begin with a number. Just keep this in mind!
# !! Obviously, the data.frame() function does not like the defined colums to be numbers...
data.frame.empty.with.colnames = function(columnames) {
	# Coerce argument "columnames" into character vector
	columnames=as.vector(columnames)
	
	# Create dummy dataframe with appropriate number of columns and filled with 
	dataframe = data.frame(matrix(vector(), 0, length(columnames), dimnames=list(c(), columnames)), stringsAsFactors=F)
	
	# Return the dataframe
	return(dataframe)
}
