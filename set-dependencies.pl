#!/usr/local/bin/perl -w
#
# $Id: set-dependencies.pl,v 1.1 2011-02-06 14:54:28 dan Exp $
#
# Copyright (c) 1999-2008 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;
use port_dependencies;

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
    FROM ports_active";

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
		$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0);

		if ($result == 0) {
			$port->update_depends();
		} else {
			print "we couldn't RefreshFromFiles\n";
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
		# the above should die if it fails, otherwise
		die('ReportError failed to die');
	}
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();
