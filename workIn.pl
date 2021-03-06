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

MyLogger::level(5, 2);

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

my $modeTest = 0;
	INFO! "$listUniv";
foreach my $univ (split(" ", $listUniv) ){
	INFO! "create object univ for $univ" ;
	my $ftpRep = $properties-> getProperty("${univ}.ftp.rep") or  FATAL!  "${univ}.ftp.rep propertie not found" ;
	my $filePrefix = $properties-> getProperty("${univ}.file.prefix") or FATAL!  "${univ}.file.prefix propertie not found" ;
	my $newPathTest = $properties-> getProperty("${univ}.test.newPath");
	
	if ($newPathTest) {
		$modeTest = 1;
		new Univ($univ, $ftpRep, $workingDir, $filePrefix)->path($newPathTest);
	} else {
		new Univ($univ, $ftpRep, $workingDir, $filePrefix);
	}
}

my $ftp = "/usr/bin/sftp -b- $ftpAddr";



=begin
	Recuperation des fichiers.zip de chaque univ
=cut

unless ($modeTest) { # on est en test pas de download

	Download::openFtp($ftp);

	foreach my $univ (Univ::all) {
		my $newPath = Download::initRepZip($univ->path, $univ->ftpRep, $univ->zipPrefix);
		if ($newPath) {
			$univ->path($newPath);
			DEBUG! "new path = " . $univ->path() . "\n";
		} else {
			# on vide le path pour indiqu?? qu'il n'y a pas de nouveau fichier
			$univ->path("");
		}
	}

	Download::closeFtp();
}




=begin
 	Traitement principal
	pour chaque univ parse les fichiers FORMATION , ETU et STAFF
	zip le repertoire r??sultat
=cut

TRAITEMENT: foreach my $univ (Univ::all) {
	my $newPath = $univ->path();
	INFO! "$newPath";
	if ($newPath =~ /^${workingDir}\/(.+)/) {
		my $relativePath=$1;
		my ($formationFile, $prefixFile, $dateFile) = findInfoFile($newPath);
		if ($formationFile) {
			Formation::readFile($newPath, $formationFile, $univ->sepChar());
			Formation::writeFile($univ, $dateFile);
			Traitement::parseFile('ETU', $univ ,  $dateFile, $annee);
			Traitement::parseFile('STAFF', $univ ,  $dateFile, $annee);
			my $zipName = lc($relativePath). '.zip';
			SYSTEM! ("cd $workingDir; /usr/bin/zip -qq -r ${zipName} ${relativePath}*");
		}
	} else {
		ERROR! $univ->id(), " KO; $workingDir";
	}
}


=begin
	Recherche du fichier FORMATION en deduit le pr??fix et la date.
=cut
sub findInfoFile {
	my $rep = shift;
	print "\n:" ,$rep , ":\n";
	opendir REP, $rep;
	foreach my $file (readdir(REP) ) {
		print "\t$file\t";
		if ($file =~ /^(.+?)_(\d{8})_FORMATIONS.csv$/) {
			closedir REP;
			return ($file, $1, $2);
		}
	}
	ERROR!  "fichier des formations non trouv?? dans :$rep\n";
	closedir REP;
	return 0;
}
