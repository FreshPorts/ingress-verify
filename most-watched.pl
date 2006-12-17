#!/usr/bin/perl -w
#
# $Id: most-watched.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2005 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;

my $dbh;

my $sql;
my $sth;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "
  SELECT C.name || '/' || E.name as port, count(WLE.element_id) as count
    FROM ports P, element E, categories C, watch_list_element WLE
   WHERE P.element_id   = WLE.element_id
     AND P.category_id  = C.id
     AND WLE.element_id = E.id
     AND E.status       = 'A'
GROUP BY C.name, E.name
ORDER BY 2 desc;";

#print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (my $row = $sth->fetchrow_hashref) {
	print $row->{'port'} . "\t" . $row->{'count'} . "\n";
}

$sth->finish();

$dbh->disconnect();

