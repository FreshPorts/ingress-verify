#!/usr/local/bin/perl -w
#
# $Id: set-broken.pl,v 1.2 2006-12-17 12:04:06 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;
use FreshPorts::port;
use DBI;
use FreshPorts::database;

# for testing results from file existance
use Scalar::Util qw(looks_like_number);


my $dbh;

my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;
my $REPODIR_CHROOT = FreshPorts::Branches::GetPathToRepoForBranchCHROOT('ports', 'main');
my $ErrorMessage = '';	# stores the result of the latest make command


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

my $pkgmessage;
my $options_name;

foreach $porttorefresh (@PORTS) {
	my $result;

	print "found $porttorefresh\n";
	$ErrorMessage = '';	# stores the result of the latest make command


	my ($port_id, $category_name, $port_name) = split /\t/,$porttorefresh, 3;
	
	my $TmpFile = FreshPorts::Utilities::TmpFileName("$category_name.$port_name.make-error");

	my $makecommand = "/usr/local/bin/sudo /usr/sbin/chroot -u $FreshPorts::Config::JailUser $FreshPorts::Config::JailBaseDir $FreshPorts::Config::JailPortScript $REPODIR_CHROOT $category_name/$port_name 2>$TmpFile";
	my $MakeResults = `$makecommand`;
	# save this for later reference
	$result = $?;

	print 'Result = ' . $result . "\n";
	#
	# if we get an error such as this: "/usr/home/dan/ports/french/homard/Makefile", line 56: Need an operator
	# (caused by spaces instead of tabs in a section such as do-install:), then $MakeResults will be empty
	# and the errors will be captured in the tmp file we created.
	#
	if ($result != 0) {
		#
		# Some errors aren't caught by the Makefile script, but are grabbed in the tmp file
		# Such as:
		# -s: not found
		# "/usr/home/dan/ports/french/homard/Makefile", line 39: warning: " -s"
		# returned non-zero status
		# caused by doing:     unames!= ${UNAME} -s
		# without first doing: .include  <bsd.port.pre.mk>
		#

		print 'size is ' . -s $TmpFile;
		print "\n";

		if (-s $TmpFile > 0) {
			print "getting error message from temp file\n";
			$ErrorMessage = "Error message is: " . `cat $TmpFile`;
		}

		if ($MakeResults ne '') {
			# save the results for error reporting
			$ErrorMessage .= "Make results are : " . $MakeResults;
		}

		$ErrorMessage = "This command (FreshPorts code 1):\n\n$makecommand\n\nproduced this error:\n\n$ErrorMessage";
		FreshPorts::CommitterOptIn::RecordErrorDetails("$category_name/$port_name", $ErrorMessage);
		$result = -1;
	}

	# remove that error collection file
	unlink($TmpFile);

	if ($result == 0) {

		(my $portname,       my $packagename,        my $descrpath,            my $categories,
		 my $portversion,    my $portrevision,       my $shortdescription,     my $CommentFile,
		 my $maintainer,     my $extractsuffix,      my $builddepends,         my $rundepends,
		 my $libdepends,     my $forbidden,          my $broken,               my $deprecated,
		 my $ignore,         my $master_port,        my $latest_link,          my $no_latest_link,
		 my $no_package,     my $pkgnameprefix,      my $pkgnamesuffix,        my $portepoch,
		 my $restricted,     my $no_cdrom,           my $expiration_date,      my $is_interactive,
		 my $only_for_archs, my $not_for_archs,      my $license,              my $fetchdepends, 
		 my $extractdepends, my $patchdepends,       my $uses,                 my $pkgmessagepath,
		 my $distinfo_file,  my $license_restricted, my $manual_package_build, my $license_perms,
		 my $conflicts,      my $conflicts_build,    my $conflicts_install,       $options_name) = split(/\n/s, $MakeResults);

		$pkgmessagepath =~ s|//|/|g;

		print "\$pkgmessagepath='$pkgmessagepath'\n";
		my $RealPKGMESSAGEPath = $port->_GetRealPath($FreshPorts::Config::RepoDir . '/' . $pkgmessagepath);
		print "\$RealPKGMESSAGEPath='$RealPKGMESSAGEPath'\n";

		# if it's defined, and it exists....
		$pkgmessage = '';
		if (looks_like_number($pkgmessagepath))
		{
                  print "PKGMESSAGE file does not exist: '$pkgmessagepath' (result of make -V PKGMESSAGE)\n";
                  #continue;
	  	}
		else
		{
                   print "pkgmessagepath does look like a valid file to me: '$pkgmessagepath' (result of make -V PKGMESSAGE)\n";
                   if ($RealPKGMESSAGEPath) {
                      #continue;
                   } else {
                      print "but _GetRealPath() claims that file does not exist. Perhaps it is '*/work/pkg-message.server' or similar\n";
                      if (index($pkgmessagepath, '/work/') != -1 ) {
                         print "Yes, yes it does contain '/work/' - let's try a make apply-slist\n";
                         $makecommand = "/usr/local/bin/sudo /usr/sbin/chroot -u $FreshPorts::Config::JailUser $FreshPorts::Config::JailBaseDir $FreshPorts::Config::JailApplySList $REPODIR_CHROOT $category_name/$port_name $pkgmessagepath 2>$TmpFile";
                         print "makecommand = $makecommand\n";
                         $pkgmessage=`$makecommand`;
                         $result = $?;
                         print 'Result = ' . $result . "\n";
                         
                         if ($result == 0) {
                           print "success, we have\n'$pkgmessage'\n";
                         }
                      } # in /work/
                   } # else not RealPKGMESSAGEPath
		} # pkgmessagepath is not a number

		chomp($pkgmessage); # get rid of the trailing whitespace.
	}

	# if we get this far, we have something for pkg-message	
	$port->{id} = $port_id;
	if ($port->FetchByID()) {

		$sql = "SET CLIENT_ENCODING TO 'SQL_ASCII';update ports set options_name = " .  $dbh->quote($options_name);

		if ($pkgmessage ne '') {
			print "$category_name/$port_name gives $pkgmessage\n";
			$sql .= ", pkgmessage = " . $dbh->quote($pkgmessage);
		}

		$sql .= " where id = $port_id";
					
		print "$sql\n";
		$sth = $dbh->prepare($sql);
		$sth->execute || FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);
		$dbh->commit();
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}

$sth->finish();

$dbh->disconnect();
