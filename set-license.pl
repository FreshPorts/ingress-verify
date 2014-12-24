#!/usr/bin/perl -w
#
# $Id: set-license.pl,v 1.1 2010-09-16 16:29:58 dan Exp $
#
# Copyright (c) 1999-2008 DVL Software
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
ORDER BY name";

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
	
		my $ExistingLicense = $port->{license};

		# needs_refresh = 0, and fetch_files = 0
		$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0);
		# print "has been refreshed ($result)\n";

		if ($result == 0) {
			if (!defined($port->{license}) || $port->{license} eq '') {
				$sql = "update ports set license = NULL where id = $port_id";
			} else {
				$sql = "update ports set license = " . $dbh->quote($port->{license}) .
					" where id = $port_id";
			}
			print $sql . "\n";
			$sth = $dbh->prepare($sql);
			$sth->execute ||
				FreshPorts::Utilities::ReportError('err', "Could not execute SQL: $sql ::  ... maybe invalid?", 1);
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
