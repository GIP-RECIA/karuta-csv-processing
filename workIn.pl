#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use MyLogger;
use Config::Properties;

use univ;
use download;
use formation;
use traitementCsv;

MyLogger::level(4, 2);

my $workingDir = shift;

unless ($workingDir) {
	die "il manque le repertoire de travail \n";
}
MyLogger::file "$workingDir/karuta.log";

my $configFile = "$workingDir/karuta.properties";

 INFO! "Lecture des properties";
open PROPS, "$configFile" or die "$configFile : " . $! . "\n";

my $properties = new Config::Properties();
$properties->load(*PROPS);

my $logFile = $properties-> getProperty('log.file');

if ($logFile) {
	INFO! "new logger file : ", $logFile;
	MyLogger::file $logFile;
}

my $ftpAddr = $properties-> getProperty('ftp.addr') or FATAL!  "ftp.addr propertie not found" ;
my $listUniv= $properties-> getProperty('univ.list') or FATAL!  "univ.list propertie not found" ;
my $annee= $properties-> getProperty('annee.scolaire') or FATAL!  "annee.scolaire propertie not found" ;

	INFO! "$listUniv";
foreach my $univ (split(" ", $listUniv) ){
	INFO! "create object univ for $univ" ;
	my $ftpRep = $properties-> getProperty("${univ}.ftp.rep") or  FATAL!  "${univ}.ftp.rep propertie not found" ;
	my $filePrefix = $properties-> getProperty("${univ}.file.prefix") or FATAL!  "${univ}.file.prefix propertie not found" ;
	new Univ($univ, $ftpRep, $workingDir, $filePrefix);
}

my $ftp = "/usr/bin/sftp -b- $ftpAddr";

Download::openFtp($ftp);

foreach my $univ (Univ::all) {
	my $newPath = Download::initRepZip($univ->path, $univ->ftpRep, $univ->zipPrefix);
	if ($newPath) {
		$univ->path($newPath);
		DEBUG! "new path = " . $univ->path() . "\n";
	} else {
		# on vide le path pour indiqué qu'il n'y a pas de nouveau fichiers
		$univ->path("");
	}
}

Download::closeFtp();

foreach my $univ (Univ::all) {
	my $newPath = $univ->path();
	if ($newPath =~ /^$workingDir\/(.+)/) {
		my $relativePath=$1;
		my ($formationFile, $prefixFile, $dateFile) = findInfoFile($newPath);
		if ($formationFile) {
			Formation::readFile($newPath, $formationFile, $univ->sepChar());
			Traitement::parseFile('ETU', $univ ,  $dateFile, $annee);
			Traitement::parseFile('STAFF', $univ ,  $dateFile, $annee);
			SYSTEM! ("cd $workingDir; /usr/bin/zip -qq -r ${relativePath}.zip ${relativePath}*");
		}
	}
}

sub findInfoFile {
	my $rep = shift;
	opendir REP, $rep;
	foreach my $file (readdir(REP) ) {
		if ($file =~ /^(\D)+([^_]+)_FORMATIONS.csv$/) {
			closedir REP;
			return ($file, $1, $2);
		}
	}
	ERROR!  "fichier des formations non trouvé dans :$rep\n";
	closedir REP;
	return 0;
}
