#!/usr/bin/perl -w
#
# $Id: set-expiration-date.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;
use lib "../";
use port;
use DBI;
use database;
use utilities;
use branches;

my $dbh;

my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;

sub ValueHasChanged($;$) {
  my $Before = shift;
  my $After  = shift;

  # if both defined, then just compare
  if (defined($Before) && defined($After)) {
    if ($Before ne $After) {
       print "A != B\n";
       return 1;
    }
  } else {
    # if no longer defined, set
    if (defined($Before) && $Before ne '' && !defined($After)) {
       print "A not defined, but B was\n";
       return 1;
    } else {
       # if now defined, set
       if (!defined($Before) && defined($After) && $After ne '') {
       print "B not defined, but A was\n";
          return 1;
       }
    }
  }

  # this means no change:
  # - still not defined
  # - defined, and no change
  return 0;
}

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
	
		my $ExpirationDateCurrent = $port->{expiration_date};

		# head, needs_refresh = 0, fetch_files = 0, svn_revision is not used since needs_refresh is 0
		$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0, '');
		print "has been refreshed ($result)\n";

		if ($result == 0) {
			if (ValueHasChanged($ExpirationDateCurrent, $port->{expiration_date})) {
#				print "updating " . $port->category . '/' . $port->name . "\n";
				$sql = "update ports set expiration_date = " . $dbh->quote($port->{expiration_date}) . " where id = $port_id";
				$sth = $dbh->prepare($sql);
				$sth->execute || FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

				$dbh->commit();
			}
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
