It's often difficult to remember how to use these tools as they are
infrequently run.

This compares the files on disk with those in the database:

ListOfPortsFromDisk.sh creates ~/list-of-ports.txt which is of the form

archivers/9e
archivers/arc
archivers/arj

Then use this data thusly:

cat ~/list-of-ports.txt  | perl CompareListofPortsWithDatabase.pl


We could do the same thing with INDEX by doing this:

cat ~/INDEX  | perl CompareListofPortsWithDatabase.pl -I
