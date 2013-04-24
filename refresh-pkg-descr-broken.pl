#!/usr/bin/perl -w
#
# $Id: refresh-pkg-descr-broken.pl,v 1.1 2013-04-24 12:22:09 dan Exp $
#
# Copyright (c) 1999-2012 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;
use system_status;

my $dbh;

my $porttorefresh;
my @PORTS;
my %Port;
my $sql;
my $sth;
my @row;

FreshPorts::Utilities::InitSyslog();

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "
 SELECT distinct P.id, C.name as category, E.name as port 
FROM commit_log_ports CLP JOIN ports      P  ON CLP.port_id  = P.id
                          JOIN commit_log CL ON CLP.commit_log_id = CL.id
                          JOIN element    E  ON P.element_id  = E.id
                          JOIN categories C  ON P.category_id = C.id
                          JOIN element    CE on C.element_id  = CE.id

WHERE CL.message_id IN
(SELECT CL.message_id
FROM commit_log_elements CLE JOIN element    E   ON CLE.element_id    = E.id
                             JOIN commit_log CL  ON CLE.commit_log_id = CL.id
WHERE E.name = 'pkg-descr'
  AND CL.date_added > '2013-03-22')
ORDER BY 1;
";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
	print "now processing @row\n";
	$Port{id}            = $row[0];
	$Port{category}      = $row[1];
	$Port{port}          = $row[2];

	#
	# by enclosing the has in { }
	# we are creating an anonymous hash
	#
	push @PORTS, {%Port};
}
 
my $port				= FreshPorts::Port->new($dbh);
my $element				= FreshPorts::Element->new($dbh);

foreach $porttorefresh (@PORTS) {
	my $result;

	my $port_id       = $porttorefresh->{id};
	my $category_name = $porttorefresh->{category};
	my $port_name     = $porttorefresh->{port};

	print "found $category_name/$port_name\n";

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$result = 0;
		$element->{id} = $port->{element_id};
		if (defined($element->FetchByID())) {
			if ($element->{status} eq $FreshPorts::Element::Deleted) {
				#
				# this port is deleted but needs refresh.
				#
				print "that port has been deleted and will not be refreshed\n";
				$result = 0;
			} else {
				$result = $port->RefreshFromFiles(1, 0); # needs refresh, don't refresh
				print "refresh attempt done ($result)\n";
			}
		} else {
			FreshPorts::Utilities::ReportError('warning', "Could not retrieve element ($port_id, $category_name, $port_name)", 1);
		}

		#
		# now reset refreshed
		#
		if ($result == 0) {

			$port->save();

			$dbh->commit();
		} else {
			print "update result is $result ******************************************\n";
			$dbh->rollback();
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}

$sth->finish();

$dbh->disconnect();
