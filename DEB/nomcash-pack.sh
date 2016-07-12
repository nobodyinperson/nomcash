#!/bin/bash
# Script to rapidly package nomcash
# run this script from the git root directory


# Define variables
Version="0.1" # Version of NomCash
NomCashDir=`pwd`"/ROOT" # /-Directory of nomcash Sandbox: NomCash Source
NomCashPackageSandbox=`pwd`"/DEB/build/nomcash-SANDBOX-"`date +'%F_%H-%M-%S'` # Sandbox for Packaging
TempDir="/tmp" # Directory for temporary data
DebianFiles=$@ # Files to include into debian directory
StartDir=`pwd` # Starting directory

# Print Logo
echo -e "
##############################################
### \033[36mQuick packaging of NomCash Source code\033[0m ###
###        written by Yann Büchau          ###
###            06. Apr 2014                ###
##############################################
"

# Check whether there are parameters at all, otherwise set defaults
if [ -z "$DebianFiles" ]; then
	echo -e " \033[31mError: \033[0mNo files given as parameters! You have to specify files you would like to include in the debian/ directory just by using them as arguments!"
	exit
fi


# Check parameters for existence and fileishness
for file in $DebianFiles; do
	if [ ! -e $file ]; then
		echo -e "\033[31mError: \033[0mParameter file \033[1m$file\033[0m does not exist! Please check parameters! Exiting..."
		exit 1
	fi
	if [ ! -f $file ]; then
		echo -e "\033[31mError: \033[0mParameter \033[1m$file\033[0m is no file! Please check parameters! Exiting..."
		exit 1		
	fi
done



# Check for the existence of Source directory
if [ ! -e $NomCashDir ]; then 
	echo "The source directory $NomCashDir does not exist!"
	exit 1
fi

# Create Sandbox folder
echo
echo -n "Creating sandbox directory \"$NomCashPackageSandbox\" ... "
mkdir -p $NomCashPackageSandbox # Create the folder
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not create sandbox directory $NomCashPackageSandbox!"
	exit 1;
fi

# Create version folder in Sandbox folder
echo
echo -n "Creating version directory \"$NomCashPackageSandbox/nomcash-$Version\" ... "
mkdir -p $NomCashPackageSandbox/nomcash-$Version # Create the folder
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not create version directory $NomCashPackageSandbox/nomcash-$Version!"
	exit 1;
fi

echo

# Prepare Source for copying into sandbox
# First, copy it to TempDir
echo -n "Copying Source code to temporary directory \"$TempDir\" ... "
mkdir -p $TempDir/nomcash/ && cp -r $NomCashDir/* $TempDir/nomcash/
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not copy NomCash source to temp directory!"
	exit 1;
fi

echo

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!! In theory, not needed anymore, because of a better Sandbox-folder-detection in the main NomCash executable !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Second, adjust $SANDBOX-Variable in main programs in temp directory in /usr/bin
#echo -n "Empty \$SANDBOX-Variable in every main program in temp directory under $TempDir/$NomCashDir/usr/bin/ ... "
#
## Iterate over every FILE you find in bin-directory of Source directory (except symbolic links)
#for file in `find $TempDir/nomcash/usr/bin/ -type f`; do
#	cat $file | perl -pe 's|(\$SANDBOX\s+=\s+)"[^"]+"|$1"/"|' > "$file-NO-SANDBOX" && # create changed temp file
#	cat "$file-NO-SANDBOX" > $file # write changed file to original temp file
#	if [ $? = 0 ]; then
#		echo -e "\033[32mdone!\033[0m"
#	else
#		echo -e "\033[31mfail!\033[0m"
#		echo "Could not adjust the \$SANDBOX-Variable in file $file!"
#		exit 1;
#	fi
#
#	# Remove tempfile
#	rm "$TempDir/nomcash/usr/bin/nomcash-gtk-NO-SANDBOX"
#	if [ $? -ne 0 ]; then
#		echo -e "\033[33mProblem:\033[0m Could not remove temporary file $file-NO-SANDBOX, exiting..."
#		exit 1;
#	fi
#done

# Now source is ready to copy to Packaging-Sandbox

# Copy modified source from temp directory to Packaging-Sandbox
echo -n "Copying adjusted sourcefolder $TempDir/nomcash/usr from tempdir $TempDir/nomcash to packaging sandbox $NomCashPackageSandbox/nomcash-$Version ... "
cp -r $TempDir/nomcash/usr $NomCashPackageSandbox/nomcash-$Version/
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not copy NomCash usr/ folder from tempdir $TempDir/nomcash/usr to packaging sandbox $NomCashPackageSandbox/nomcash-$Version!"
	exit 1;
fi


# Clear created temp directory
echo
echo -n "Removing created tempfiles ... "
rm -r "$TempDir/nomcash/"
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[33mwarning!\033[0m"
	echo "Could not remove tempfiles... but never mind :-) "
fi


# Compress source in Sandbox to .tar.gz archive
echo
echo "Archiving usr/ source folder in Sandbox to .tar.gz archive ... "
echo "Tar output:"
cd "$NomCashPackageSandbox/" && # Change directory into Version folder
tar -cvzf "nomcash-$Version/nomcash-$Version.tar.gz" nomcash-$Version/usr/ # Archive usr/ folder
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not archive NomCash usr/ folder in packaging sandbox to tar.gz archive!"
	exit 1;
fi


# Debianzie Version directory with dh_make
# Do that in the right directory
cd "$NomCashPackageSandbox/nomcash-$Version"
echo
echo "Debianizing directory `pwd` with dh_make."
echo "dh_make output:"
echo
dh_make -e nobodyinperson@gmx.de -c gpl3 -i -f "$NomCashPackageSandbox/nomcash-$Version/nomcash-$Version.tar.gz"
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not debianize directory `pwd`!"
	exit 1;
fi

# Remove now unecessary archive
echo
echo -n "Removing archive nomcash-$Version.tar.gz that is not needed anymore from debianized directory ... "
rm "$NomCashPackageSandbox/nomcash-$Version/nomcash-$Version.tar.gz" # Remove archive
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not remove archive nomcash-$Version.tar.gz!"
	exit 1;
fi


# Remove unnecessary example and Readme files from debian/ directory
echo
echo -n "Removing unnecessary example and README files from debian/ directory ... "
cd "$NomCashPackageSandbox/nomcash-$Version/debian/" && # change directory to debian/ directory
rm *.ex *.EX README.* # Remove files
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[33mwarning!\033[0m"
	echo "Could not remove example and readme files from debian/ directory, continuing..."
fi


# Now copy template control / copyright / rules / etc. files into debian/directory
cd $StartDir # First, change directory into initial directory
echo
echo -n "Copying template files you specified as arguments into debian/ directory ... "
cp ./$DebianFiles $NomCashPackageSandbox/nomcash-$Version/debian/
if [ $? = 0 ]; then
	echo -e "\033[32mdone!\033[0m"
else
	echo -e "\033[31mfail!\033[0m"
	echo "Could not copy template files to debian/ directory!"
	exit
fi


# Create the actual debian package with dpkg-buildpackage
cd $NomCashPackageSandbox/nomcash-$Version/ # First Change into Sandbox Version directory
### Then finally fire off the packaging command!
echo
echo "Packaging nomcash with dpkg-buildpackage ... "
fakeroot dpkg-buildpackage
#if [ $? = 0 ]; then
#	echo -e "\033[32mdone!\033[0m"
#else
#	echo -e "\033[31mfail!\033[0m"
#	echo "Could not package nomcash... pity..."
#	exit
#fi
###

# Done :-)


















