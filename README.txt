Most scripts in this directory are used to fix things. Perhaps a field
was being incorrectly updated. The code is fixed, but now you have to
clean up the database. That's what this stuff is for.

In general, stop the commit processing while this script runs.

service freshports stop

Run this via tmux, so it keeps running and you can get back to it should
your ssh connection is lost.

echo perl ./set-makefile.pl | sudo su -fm freshports > /tmp/set-makefile.log

The website will stop updating. Often, it can take 6-12 hours for all
ports to get updated.

Historically:

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
