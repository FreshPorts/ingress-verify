#!/usr/bin/perl -w
#
# $Id: set-master-port-latest-link.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;

my $dbh;

my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "
  SELECT ports_active.id,
         ports_active.category,
         ports_active.name
    FROM ports_active
ORDER BY category, name ";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
#	print "now reading @row\n";
	push @PORTS, "$row[0]\t$row[1]\t$row[2]"
}

my $port = FreshPorts::Port->new($dbh);

foreach $porttorefresh (@PORTS) {
	my $result;

	print "found $porttorefresh\n";

	my ($port_id, $category_name, $port_name) = split /\t/,$porttorefresh, 3;

	$port->{id} = $port_id;
	if ($port->FetchByID()) {

		# needs_refresh = 0, and fetch_files = 0
		$result = $port->RefreshFromFiles(0, 0);
		print "has been refreshed ($result)\n";

		if ($result == 0) {
			$sql = "update ports set master_port = " . $dbh->quote($port->{master_port}) .
					", latest_link = " . $dbh->quote($port->{latest_link}) . " where id = $port_id";
			$sth = $dbh->prepare($sql);
			$sth->execute ||
				FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

			$dbh->commit();
		} else {
			$dbh->rollback();
			print "update result is $result ******************************************\n";
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();

