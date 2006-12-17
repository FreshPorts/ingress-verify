#!/bin/sh
#
# $Id: ListOfPortsFromDisk.sh,v 1.2 2006-12-17 12:04:05 dan Exp $
#
# Copyright (c) 2001-2002 DVL Software
#
# This script will take what it finds within PORTSDIR
# and compiles a list of the ports it finds.
# It then uses this list to verify things against the 
# FreshPorts database
#

PORTSDIR=/usr/ports
TMPFILE=~/list-of-ports.txt

cd ${PORTSDIR}
find * -maxdepth 1 -type d |  \
         egrep -v "^Mk|^Templates|^Tools|^distfiles|*/pkg$" | \
         grep "/" > ${TMPFILE}

exit
cat ${TMPFILE} | perl ~/scripts/Verify/INDEX-verify-ports.pl
