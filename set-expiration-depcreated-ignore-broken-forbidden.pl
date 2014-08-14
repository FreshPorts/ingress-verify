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

sub ValueHasChanged($$)
{
   my $before = shift;
   my $after  = shift;

   return (($before // "") ne ($after // ""));
}

sub SetValueAllowingForNull($$)
{
    my $fieldName  = shift;
    my $fieldValue = shift;
    
    if (defined($fieldValue) && $fieldValue ne '') {
        $sql = $fieldName . ' = ' . $dbh->quote($fieldValue);
    } else {
        $sql = $fieldName . ' = NULL';
    }

    return $sql;
}         
         
FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "
  SELECT P.id,
         P.category,
         P.name
    FROM ports_active P JOIN element E           ON P.element_id = E.id
                        JOIN element_pathname EP ON E.id         = EP.element_id
   WHERE EP.pathname like '/ports/head/%'
ORDER BY P.category, E.name";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
#	print "now reading @row\n";
	push @PORTS, "$row[0]\t$row[1]\t$row[2]"
}

my $NumToProcess = scalar(@PORTS);
Sys::Syslog::syslog('notice', "There are $NumToProcess ports to process");

my $port = FreshPorts::Port->new($dbh);

my $num = 0;

foreach $porttorefresh (@PORTS) {
	my $result;
	
	$num++;

	print "found $porttorefresh\n";
	if (($num % 100) == 0) {
    	Sys::Syslog::syslog('notice', "processing $num of $NumToProcess ports: $porttorefresh\n");
    }
    
	my ($port_id, $category_name, $port_name) = split /\t/,$porttorefresh, 3;

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
	
	    if ($port->IsDeleted()) {
	        # because of branches, we sometimes get caught up on branches, and we want only head.
	        next;
        }
	
		my $ExpirationDateCurrent = $port->{expiration_date};
		my $DeprecatedCurrent     = $port->{deprecated};
		my $IgnoreCurrent         = $port->{ignore};
		my $BrokenCurrent         = $port->{broken};
		my $ForbiddenCurrent      = $port->{forbidden};

		# head, needs_refresh = 0, fetch_files = 0, svn_revision is not used since needs_refresh is 0
		$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0, '');
		print "has been refreshed ($result)\n";
		
		my $FieldUpdates = '';

		if ($result == 0) {
		    if (ValueHasChanged($ExpirationDateCurrent, $port->{expiration_date})) {
		        $FieldUpdates .= ', ' . SetValueAllowingForNull('expiration_date', $port->{expiration_date});
		    }

		    if (ValueHasChanged($DeprecatedCurrent, $port->{deprecated})) {
		        $FieldUpdates .= ', ' . SetValueAllowingForNull('deprecated', $port->{deprecated});
		    }

		    if (ValueHasChanged($IgnoreCurrent, $port->{ignore})) {
		        $FieldUpdates .= ', ' . SetValueAllowingForNull('ignore', $port->{ignore});
		    }

		    if (ValueHasChanged($BrokenCurrent, $port->{broken})) {
		        $FieldUpdates .= ', ' . SetValueAllowingForNull('broken', $port->{broken});
		    }

		    if (ValueHasChanged($ForbiddenCurrent, $port->{forbidden})) {
		        $FieldUpdates .= ', ' . SetValueAllowingForNull('forbidden', $port->{forbidden});
		    }

			if ($FieldUpdates ne '') {
			    # remove the leading ', '
			    $FieldUpdates = substr($FieldUpdates, 2);
#				print "updating " . $port->category . '/' . $port->name . "\n";

            	Sys::Syslog::syslog('notice', "updating $category_name/$port_name");

				$sql = 'update ports set ' . $FieldUpdates . " where id = $port_id";
				$sth = $dbh->prepare($sql);
				$sth->execute || FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

#				$dbh->commit();
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

Sys::Syslog::syslog('notice', "finished");
