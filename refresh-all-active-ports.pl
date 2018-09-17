#!/usr/local/bin/perl -w
#
# $Id: set-libdepends.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;
use constants;
use branches;

my $dbh;

my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;

my $previousBranch;
my $currentBranch  = $FreshPorts::Constants::HEAD;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

#
# get a list of ports to update
#

$sql = "
  SELECT ports_active.id,
         ports_active.category,
         ports_active.name,
         element_pathname(ports_active.element_id) as port_pathname
    FROM ports_active
ORDER BY category, name ";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
#	print "now reading @row\n";
	push @PORTS, "$row[0]\t$row[1]\t$row[2]\t$row[3]"
}

my $port = FreshPorts::Port->new($dbh);

foreach $porttorefresh (@PORTS) {
	my $result;

	print "found $porttorefresh\n";

	my ($port_id, $category_name, $port_name, $port_pathname) = split /\t/,$porttorefresh, 4;

    $previousBranch  = $currentBranch;
	my $currentBranch = FreshPorts::Branches::GetBranchFromPathName($port_pathname);
    print "Setting branch: '$currentBranch'\n";
    FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

	$port->{id} = $port_id;

	if ($port->FetchByID()) {

		# needs_refresh = 0, and fetch_files = 0
		$result = $port->RefreshFromFiles($currentBranch, 0, 0);
		print "has been refreshed ($result)\n";

	    $port->save($currentBranch);
            $dbh->commit();
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}

$dbh->commit();
$sth->finish();

$dbh->disconnect();
