#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2024 Dan Langille
#

use strict;
use lib "../";
use port;
use DBI;
use database;
#use utilities;

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
    FROM ports_active join ports on ports_active.id = ports.id and ports.use_rc_subr is null
ORDER BY category, name ";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
#	print "now reading @row\n";
	push @PORTS, "$row[0]\t$row[1]\t$row[2]"
}

my $port = FreshPorts::Port->new($dbh, 'git');

foreach $porttorefresh (@PORTS) {
	my $result;

	print "found $porttorefresh\n";

	my ($port_id, $category_name, $port_name) = split /\t/,$porttorefresh, 3;

	$port->{id} = $port_id;
	if ($port->FetchByID()) {

		# needs_refresh = 0, and fetch_files = 0
		$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0);
		print "has been refreshed ($result)\n";

		# only save it there is a value to save - we are setting this field for the first time.
		if ($result == 0 && defined($port->{use_rc_subr}) && length($port->{use_rc_subr})) {
			$sql = "update ports set use_rc_subr = " . $dbh->quote($port->{use_rc_subr}) .
					" where id = $port_id";
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

