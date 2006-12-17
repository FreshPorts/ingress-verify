#!/usr/bin/perl -w
#
# $Id: look-for-deleted-ports.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
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

my $port;
my @PORTS;
my $sql;
my $sth;
my $row;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "
SELECT P.id     AS port_id,
       E.id     AS element_id,
       E.name   AS port, 
       C.name   AS category, 
       E.status AS status
  FROM ports P, element E, categories C
 WHERE P.element_id  = E.id
   AND P.category_id = C.id
ORDER by category, port
";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while ($row=$sth->fetchrow_hashref) {
#	print "now reading @row\n";
	my $port = $row;
	push @PORTS, $row;
}

foreach $port (@PORTS) {
	my $result;

	print 'P.id:' . $port->{port_id} . ' E.id:' . $port->{element_id} . ' ' . $port->{category} . '/' . $port->{port} . ': ' . $port->{status} . "\n";
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();

