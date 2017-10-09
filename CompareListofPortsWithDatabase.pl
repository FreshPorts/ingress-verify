#!/usr/local/bin/perl -w
#
# $Id: CompareListofPortsWithDatabase.pl,v 1.2 2006-12-17 12:04:05 dan Exp $
#
# Copyright (c) 2001-2002 DVL Software
#

use strict;
use lib "../";
#require port;
require DBI;
require database;

my %PortsDB;
my %PortsDisk;

sub ExtractPortFromLine($) {
	my $IndexLine = shift;

	(my $version, my $pathname, my $rest) = split(/\|/, $IndexLine);
#	print "$version, $pathname, $rest\n";
	print "$pathname => ";

	(my $extra, my $usr, my $ports, my $category, my $port) = split ("/", $pathname);

	return "$category/$port";
}

my $sth;
my $sql;
my $IndexLine;
my $IndexFile = 0;

for (my $i = 0; $i < ($#ARGV+1); $i++) {
	print "checking arg $i\n";
	if ($ARGV[$i] eq '-I') {
		print "debugging....\n";
		$IndexFile = 1;
	}
}

my $dbh = DBI->connect('DBI:Pg:dbname=fp2migration', 'dan', '', {AutoCommit => 0});


if ($dbh) {
	print "connected\n";

	print "now setting up things....\n";

	$dbh->rollback();

	$sql = "select PortVerifyBegin()";
	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

	print "reading from STDIN...\n";
	while (defined(my $IndexLine = <STDIN> ) ) {
		# remove the trailing CR/LF
		$IndexLine =~ s/\n//g;

		my $result;
		if ($IndexFile) {
			$result = ExtractPortFromLine($IndexLine);
		} else {
			$result = $IndexLine;
		}

		print "found $result\n";

		# record this port as not being found in the db.
		$PortsDisk{$result} = 0;
	}

	$sql = "select id, name, category from ports_active order by category, name";
	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);


	print "reading from database...\n";
	my @row;
	while (@row=$sth->fetchrow_array) {
		$PortsDB{"$row[2]/$row[1]"} = $row[0];
	}

	print "comparing...\n";


	my %PortsInDBNotOnDisk;
	my %PortsOnDiskNotInDB;

	my $MissingFromDisk = 0;
	my $MissingFromDB   = 0;

	my $CatPort;
	my $ID;
	while (($CatPort, $ID) = each %PortsDB) {
		if (!defined($PortsDisk{$CatPort})) {
			print "not found on Disk : $CatPort\n";
			$PortsInDBNotOnDisk{$CatPort} = 1;
			$MissingFromDisk++;

			$sql = "update ports set found_in_index = FALSE where id = $ID";
	        $sth = $dbh->prepare($sql);
    	    $sth->execute ||
        	    FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);
		}
	}

	while (($CatPort, $ID) = each %PortsDisk) {
		if (!defined($PortsDB{$CatPort})) {
			print "not found in Database : $CatPort\n";
			$PortsOnDiskNotInDB{$CatPort} = 1;
			$MissingFromDB++;

			(my $category, my $port) = split ("/", $CatPort);

			$sql = "select PortVerifyAddOne('$category', '$port')";
	 		$sth = $dbh->prepare($sql);
			$sth->execute ||
				FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);
		}
	}

	print "MissingFromDisk = $MissingFromDisk\n";
	print "MissingFromDB   = $MissingFromDB\n";

	$dbh->commit();
	$sth->finish();
	$dbh->disconnect();
} else {
#	print "Cannot connect to Postgres server: $DBI::errstr\n";
	print " db connection failed\n";
}
