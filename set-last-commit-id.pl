#!/usr/bin/perl -w
#
# $Id: set-last-commit-id.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

#
# I found that several (about 800-900) ports did not yet have last_commit_id set.
# this script sets that.
#

use strict;
use lib "$ENV{HOME}/scripts";
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
  SELECT id
    FROM ports
   WHERE last_commit_id IS NULL
";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
	print "now reading @row\n";
	push @PORTS, "$row[0]"
}

my $port = FreshPorts::Port->new($dbh);

foreach $porttorefresh (@PORTS) {
	$sql = "
SELECT max(CL.commit_date)
  FROM commit_log CL, commit_log_ports CLP
 WHERE CLP.port_id = $porttorefresh
   AND CL.id       = CLP.commit_log_id
";

	print "sql = $sql\n";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

	@row =$sth->fetchrow_array;

	my $CommitLogDate = $row[0];

	$sql = "
SELECT CL.id
  FROM commit_log CL, commit_log_ports CLP
 WHERE CLP.port_id = $porttorefresh
   AND CL.id       = CLP.commit_log_id
   AND CL.commit_date = '$CommitLogDate'
";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

	@row =$sth->fetchrow_array;

	my $CommitLogID = $row[0];

	$sql = "
UPDATE ports
   SET last_commit_id = $CommitLogID
 WHERE id             = $porttorefresh
";

	print "sql = $sql\n";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

}

$sth->finish();

$dbh->commit();
$dbh->disconnect();

