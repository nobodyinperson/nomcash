# nomcash
A GTK application written in Perl to keep an eye on your money.

**Note**: This application is in development state and currently not really functional.

## Structure

**ROOT**/ 

- FHS folder structure with all nomcash files in the appropriate locations.

**DEB**/

- script and files needed to package nomcash into a .deb package.
- **nomcash-templates/***: files needed for debian packaging
- **nomcash-pack.sh**: run this script from the repository root with all files in **nomcash-templates** as argument to build the package and produce a .deb package.
