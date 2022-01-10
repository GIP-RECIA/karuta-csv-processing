use strict;

=begin

recuperation de fichier du ftp et dézipage

=cut


package Download;
use IPC::Open2;

my $date='00000000';

# le repertoire de destination
my $repZip;
my $ftpPrompt;
my $ftpHomeRep;

my $FTPin;
my $FTPout;

sub initRepZip {
	$repZip = shift;
	my $ftpRep = shift;

	# on regarde les fichiers.zip existant
	my %lastZipByPrefix;
	my %lastDateByPrefix;
	my %newZipByPrefix;
	opendir (REP, $repZip);

	foreach my $file (readdir(REP) ) {
		&filtreFile(\%lastZipByPrefix, \%lastDateByPrefix, $file);
	}

	# lit le repertoire  ftp:
	foreach my $file (ftpRead($ftpRep)) {
	#	print "..$file..\n";
		&filtreFile(\%newZipByPrefix, \%lastDateByPrefix, $file);
	}
	foreach my $file (values %newZipByPrefix) { # en fait il ne devrait en avoir qu'un zip 
		ftpGet("$ftpRep/$file", $repZip);
		if ($file =~ /(\w+).zip/) {
			my $newRep = "$repZip/".$1;
			mkdir ("$newRep") || die $!;
			system ("unzip -d $newRep $repZip/$file" ) ;
			return $newRep;
		}
	}
}

sub filtreFile {
	my ($lastZipByPrefix, $lastDateByPrefix, $file) = @_;
	if ($file =~ /^(\D+)(\d+)\.zip$/) {
		print $1 , "\t$2" ,"\n";
		my $prefix = $1;
		my $date = $2;
		my $lastDate = $$lastDateByPrefix{$prefix};
		unless ($lastDate && ($date le $lastDate) ) {
			$$lastDateByPrefix{$prefix} = $date;
			$$lastZipByPrefix{$prefix} = $file;
		} 
	}
}

sub openFtp {
	my $ftpCommand = shift;
	
	open2($FTPin, $FTPout, $ftpCommand) || die "erreur connexion sftp: $!\n";
	print $FTPout "\n";
	$ftpPrompt = <$FTPin>;
	chop $ftpPrompt;
	
	print "connection FTP ...\n";
	print $FTPout "pwd\n";

	while (<$FTPin>) {
#		print ;
		if (m/Remote working directory: (\/.+)$/) {
			$ftpHomeRep = $1;
			last;
		}
	}
#	print "ftpHomeRep = $ftpHomeRep \n ";
#	print "prompt = $ftpPrompt\n";
	print "\t\t  ok \n";
}

sub closeFtp {
	close $FTPin;
	close $FTPout;
}

sub ftpGet {
	my $file = shift;
	my $localRep = shift;
	
	print $FTPout "get $file $localRep \n\n";
	while (<$FTPin>) {
		last if /^$ftpPrompt$/;
		print ;
	}
}

sub ftpRead {
	my $ftpRep = shift;
	
	#  on recupere la liste des fichiers.zip
	print qq{ls *.zip\n};
	print $FTPout "ls   $ftpRep/*.zip\n\n";
	$_ = <$FTPin>;

	my @fileList;
	while (<$FTPin>) {
		last if /^$ftpPrompt$/;
		if (/((\w|[.-])+.zip)/) {
		#	print ".$1.\n";
			push @fileList, $1;
		} 
	}
#	print $FTPout "cd $ftpHomeRep \n";
#	<$FTPin>;
	
	return @fileList;
}
1;
