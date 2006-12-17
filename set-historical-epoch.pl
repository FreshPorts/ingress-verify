#!/usr/bin/perl -w
#
# $Id: set-historical-epoch.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;
use config;

sub PackageVersion($;$;$) {
	my $PortVersion  = shift;
	my $PortRevision = shift;
	my $PortEpoch    = shift;

	my $PackageVersion = '';

	if (length($PortVersion) > 0) {
    	$PackageVersion .= $PortVersion;
		if (defined($PortRevision) && length($PortRevision) > 0 && $PortRevision ne "0") {
    		$PackageVersion .= '_' . $PortRevision;
		}

		if (defined($PortEpoch)    && length($PortEpoch)    > 0 && $PortEpoch    ne "0") {
    		$PackageVersion .= ',' . $PortEpoch;
		}
	}

	return $PackageVersion;
}

sub UpdateTheEpochValueInTheCommit($;$;$) {
	my $dbh    = shift;
	my $Commit = shift;
	my $EPOCH  = shift;

	my $sql;
	my $sth;

	$sql = "
UPDATE commit_log_ports
   SET port_epoch    = $EPOCH
 WHERE commit_log_id = $Commit->{'commit_log_id'}
   AND port_id       = $Commit->{'port_id'}
";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);
	   
}

sub FetchCommitsForThisPort($;$) {
	my $dbh  = shift;
	my $Port = shift;

	my $sql;
	my $sth;

	$sql = "
    SELECT C.commit_log_id,
           C.port_id,
           C.port_version,
           C.port_revision,
           C.port_epoch,
           C.commit_date,
           C.pathname,
           M.revision_name
FROM
    (SELECT P.id,
           CLP.commit_log_id,
           CLP.port_id,
           CLP.port_version,
           CLP.port_revision,
           CLP.port_epoch,
           CL.commit_date,
           element_pathname(P.element_id, FALSE) as pathname
      FROM ports               P,
           commit_log_ports    CLP,
           commit_log          CL
     WHERE P.id              = " . $Port->{'id'} . "
       AND P.id              = CLP.port_id
       AND CLP.port_version != ''
       AND CLP.commit_log_id = CL.id) AS C left outer join

(  SELECT P.id,
         CLP.commit_log_id,
         CLP.port_id,
         CLP.port_version,
         CLP.port_revision,
         CLP.port_epoch,
         CL.commit_date,
         element_pathname(CLE.element_id, FALSE),
         CLE.revision_name
    FROM ports               P, 
         commit_log_ports    CLP,
         element             E,
         commit_log_elements CLE,
         commit_log          CL
   WHERE P.id              = " . $Port->{'id'} . "
     AND P.id              = CLP.port_id
     AND CLE.commit_log_id = CLP.commit_log_id
     AND CLE.element_id    = E.id
     AND E.name            = 'Makefile'
     AND E.parent_id       = P.element_id
     AND CLP.commit_log_id = CL.id
     AND CLP.port_version != '') AS M

on (M.commit_log_id = C.commit_log_id)

order by C.commit_date desc";

#	print "sql = $sql\n";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);


	my $PortEpochSetInSlave = 0;

	my $EPOCH = '';

	while (my $commit=$sth->fetchrow_hashref()) {
		print sprintf "commit_log_id = %8d commit_date = %s", $commit->{'commit_log_id'}, $commit->{'commit_date'};
		print sprintf "%20s", PackageVersion($commit->{'port_version'}, $commit->{'port_revision'}, $commit->{'port_epoch'});
		print " => ";
		if (defined($commit->{'revision_name'})) {
        	print 'revision_name = ' . $commit->{'revision_name'};

#			print "\n";

			my $URL     = 'http://cvsweb.unixathome.org/cgi-bin/cvsweb.cgi/~checkout~';
			my $DESTDIR = '/tmp';
			my $SRCDIR  = $commit->{'pathname'};
			my $FILE    = $FreshPorts::Constants::FILE_MAKEFILE;
			my $SUFFIX  = '\&content-type=text/plain\&cvsroot=freebsd';

			if (FreshPorts::Utilities::FetchFileURL($URL, $DESTDIR, $SRCDIR, $FILE, $commit->{'revision_name'}, $SUFFIX)) {

				$EPOCH = `grep PORTEPOCH $DESTDIR/$FILE | awk '{print \$2}'`;
				chomp $EPOCH;
				print " contains EPOCH = '$EPOCH'";

			} else {
				FreshPorts::Utilities::ReportError('warning', "Could not execute fetch file", 1);
			}

			if ($EPOCH ne '') {
				$PortEpochSetInSlave = 1;
			}
		} else {
			print 'Makefile not touched in this commit'
		}

		print "\n";

		if ($EPOCH ne '') {
			if ($EPOCH =~ m/\${.*}/) {
				print "EPOCH not set: Not updating that commit as the EPOCH value is a variable\n";
			} else {
				UpdateTheEpochValueInTheCommit($dbh, $commit, $EPOCH);
			}
		}

	}

	if (!$PortEpochSetInSlave) {
		print "%%%%%%%%%%%%%%%%%%% WARNING %%%%%%%%%%%%%%%%%%\n";
		print " This port did not set PortEpoch, anywhere.\n";
		print " Yet it has PORTEPOCH = $Port->{'portepoch'}\n";
		print " It must be set in the master port.\n";
		print "%%%%%%%%%%%%%%%%%%% WARNING %%%%%%%%%%%%%%%%%%\n";

		print "\nThe master port is $Port->{'master_port'}\n"
	}

	print "----- that's all for this port -----\n\n";
}


sub main() {
	my $dbh;

	my $sql;
	my $sth;

	FreshPorts::Utilities::InitSyslog();

	$dbh = FreshPorts::Database::GetDBHandle();

	#
	# get a list of ports to update
	#

	$sql = "
SELECT P.id,
       C.name || '/' || E.name as portname,
       P.master_port,
       P.portepoch
  FROM ports P, categories C, element E
 WHERE P.portepoch   != '0'
   AND P.category_id  = C.id
   AND P.element_id   = E.id;
";
	$sth = $dbh->prepare($sql);
	$sth->execute ||
			FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

	my $LastCommitLogID = undef;

	while (my $Port = $sth->fetchrow_hashref()) {
		print ' * * * * * *  now processing ' . $Port->{'id'} . ' => ' . $Port->{'portname'} . "\n";
		print ' http://beta.freshports.org/' . $Port->{'portname'} . "/\n";
		FetchCommitsForThisPort($dbh, $Port);
	}
	
	$sth->finish();

	$dbh->commit();
	$dbh->disconnect();

}

main();
