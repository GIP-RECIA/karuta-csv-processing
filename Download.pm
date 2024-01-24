use strict;
use MyLogger;
#use Filter::sh "tee " . __FILE__ . ".pl";
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
my $ftpPid;

my %lastZipByPrefix;
my %lastDateByPrefix;




sub initRepZip {
	$repZip = shift;
	my $ftpRep = shift;
	my $zipPrefix = shift;

	# on regarde les fichiers.zip existant
	my %newZipByPrefix;

	
	opendir (REP, $repZip);

	§INFO "Rep local = $repZip, filtre prefix: $zipPrefix\n";

	foreach my $file (readdir(REP) ) {
		§TRACE ">\t$file ...\n";
	#	if ($file =~ /${zipPrefix}_\d{8}.zip/) { #TODO le test est inutile 
			&filtreFile(\%lastZipByPrefix, \%lastDateByPrefix, $file, $zipPrefix);
	#	}
	}

	
	# lit le repertoire  ftp:
	my $nbFtpFile = 0;
	
	§INFO "Rep ftp $ftpRep filtre prefix: $zipPrefix\n";

	foreach my $file (ftpRead($ftpRep, $zipPrefix)) {
		§TRACE "test:\t$file ...\n";
		if (&filtreFile(\%newZipByPrefix, \%lastDateByPrefix, $file, $zipPrefix)) {
			if ($nbFtpFile++ > 31) {
				deleteFtpFile($ftpRep, $file);
			}
		}
	}
	
	foreach my $file (values %newZipByPrefix) { # en fait il ne devrait avoir qu'un zip 
		ftpGet("$ftpRep/$file", $repZip);
		if ($file =~ /(univ-)?(.+).zip/) {
			my $newRep = "$repZip/".$2;
			§INFO "mkdir $newRep \n";
			mkdir ("$newRep") || §FATAL  $!;
			§INFO "unzip -qq -d  $newRep $repZip/$file \n";
			§SYSTEM ("unzip -qq -d  $newRep $repZip/$file" ) ;
			return $newRep;
		}
	}
	return 0;
}

sub filtreFile {
	my ($lastZipByPrefix, $lastDateByPrefix, $file, $prefixe) = @_;
	if ($file =~ /^(${prefixe}_)(\d{8})\.zip$/) {
		§TRACE "\t\tok:\t", $1 , "\t$2" ,"\n";
		my $prefix = $1;
		my $date = $2;
		my $lastDate = $$lastDateByPrefix{$prefix};
		unless ($lastDate && ($date le $lastDate) ) {
			$$lastDateByPrefix{$prefix} = $date;
			$$lastZipByPrefix{$prefix} = $file;
		}
		return 1;
	}
	return 0;
}

sub openFtp {
	my $ftpCommand = shift;
	
	$ftpPid = open2($FTPin, $FTPout, $ftpCommand);
	print $FTPout "\n" ;
	$ftpPrompt = <$FTPin>;
	chop $ftpPrompt;

	if ($ftpPrompt) {
		§INFO "connection FTP ok";
	} else {
		§FATAL "connection FTP Ko";
	}
	print $FTPout "pwd\n";

	while (<$FTPin>) {

		if (m/Remote working directory: (\/.+)$/) {
			$ftpHomeRep = $1;
			last;
		}
	}
	
}

sub closeFtp {
	close $FTPin;
	close $FTPout;
	waitpid $ftpPid, 0;
}

sub ftpGet {
	my $file = shift;
	my $localRep = shift;

	print $FTPout "get $file $localRep \n\n";
	while (<$FTPin>) {
		last if (/^$ftpPrompt$/);
		§TRACE $_ ;
	}
}

sub deleteFtpFile {
	my $ftpRep = shift;
	my $file = shift;
	if ($file) {
		print $FTPout "rm $ftpRep/$file\n\n";
		while (<$FTPin>) {
			last if (/^$ftpPrompt$/); #
			§TRACE $_;
		}
	}
}

sub ftpRead {
	my $ftpRep = shift;
	my $zipPrefix = shift;
	
	#  on recupere la liste des fichiers.zip
	# dans l'ordre le plus recent en premier.
	# attention entraine la suppression des plus vieux (ne pas changer le -t).
	my $arg = "$ftpRep/${zipPrefix}_????????.zip";
	print $FTPout "ls  -t  $arg\n\n";
	$_ = <$FTPin>;

	my @fileList;
	while (<$FTPin>) {
		last if /^$ftpPrompt$/;
		if (/((\w|[.-])+.zip)/) {
			§TRACE "ftp: $1\n";
			push @fileList, $1;
		} 
	}
#	print $FTPout "cd $ftpHomeRep \n";
#	<$FTPin>;
	
	return @fileList;
}
1;
