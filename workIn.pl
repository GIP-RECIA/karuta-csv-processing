#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );
use File::Copy qw(copy);
use FindBin;                    
use lib $FindBin::Bin;  
use MyLogger;
use Config::Properties;
use univ;
use download;
use formation;
use traitementCsv;
use DiffCsvHeap;

MyLogger::level(5, 2);

my $workingDir = shift;

my $outSuffix = '_diff/';

unless ($workingDir) {
	die "il manque le repertoire de travail \n";
}

MyLogger::file "$workingDir/karuta.log";

my $configFile = "$workingDir/karuta.properties";

INFO! "Lecture des properties";
my $properties = new Config::Properties( file => $configFile) or FATAL! "Properties $configFile : $!";

my $logFile = $properties->getProperty('log.file');

if ($logFile) {
	INFO! "new logger file : ", $logFile;
	MyLogger::file $logFile;
}

my $ftpAddr = $properties-> getProperty('ftp.addr') or FATAL!  "ftp.addr propertie not found" ;
my $listUniv= $properties-> getProperty('univ.list') or FATAL!  "univ.list propertie not found" ;
my $annee= $properties-> getProperty('annee.scolaire') or FATAL!  "annee.scolaire propertie not found" ;
my $dataFile = $properties-> getProperty('data.file', $workingDir. "/karuta.data");

DEBUG! "datafile = $dataFile";


my $dataProps = new Config::Properties();
#lecture du fichier data s'il existe
if (-f $dataFile) {
	open my $data, $dataFile or FATAL! "error lecture $dataFile: $!";
	$dataProps->load($data);
	close $data;
}

my $modeTest = 0;

foreach my $univ (split(" ", $listUniv) ){
	INFO! "Univ a traiter: $univ" ;

	my $ftpRep = $properties-> getProperty("${univ}.ftp.rep") or  FATAL!  "${univ}.ftp.rep propertie not found" ;
	my $filePrefix = $properties-> getProperty("${univ}.file.prefix") or FATAL!  "${univ}.file.prefix propertie not found" ;
	my $newPathTest = $properties-> getProperty("${univ}.test.newPath");

	my $u = new Univ($univ, $ftpRep, $workingDir, $filePrefix);
	
	if ($newPathTest) {
		DEBUG! "newPathTest = " , $newPathTest;
		$modeTest = 1;
		$u->path($newPathTest);
		$u->lastPath($properties->getProperty("${univ}.test.lastPath"));
	} else {
		$u->lastPath($dataProps->getProperty($univ));
	}
	DEBUG! "$univ last path = ", $u->lastPath,";";
}

my $ftp = "/usr/bin/sftp -b- $ftpAddr";


=begin
	Recuperation des fichiers.zip de chaque univ
=cut

unless ($modeTest) { # si on est en test pas de download

	Download::openFtp($ftp);

	foreach my $univ (Univ::all) {
		my $newPath = Download::initRepZip($univ->path, $univ->ftpRep, $univ->zipPrefix);
		if ($newPath) {
			$univ->path($newPath);
			DEBUG! "new path = " . $univ->path() . "\n";
		} else {
			# on vide le path pour indiqué qu'il n'y a pas de nouveau fichier
			$univ->path("");
		}
	}

	Download::closeFtp();
}




=begin
 	Traitement principal
	pour chaque univ parse les fichiers FORMATION , ETU et STAFF
	zip le repertoire résultat
=cut

my %allNewPrefixFile;

TRAITEMENT: foreach my $univ (Univ::all) {
	my $newPath = $univ->path();
	
	INFO! ":$newPath", ": :${workingDir}:";
	
	my $lastPath = $univ->lastPath();

	if ($lastPath) {
		$lastPath .= $outSuffix;
		DEBUG! "ancien path : $lastPath";
	} else {
		DEBUG! "ancien path ; NVL";
	}
	
	if ($newPath =~ /^${workingDir}\/(.+)/) {
		my $relativePath=$1;
		my ($formationFile, $prefixFile, $dateFile) = findInfoFile($newPath);
		my $tmpRep = "${newPath}_tmp/";

		unless ( -d $tmpRep) {
			mkdir $tmpRep, 0775;
		}
		
		my $resRep = ${newPath}. $outSuffix ;

		unless ( -d $resRep) {
			mkdir $resRep, 0775;
		}
		
		if ($formationFile) {
			
			Formation::readFile($newPath, $formationFile, $univ->sepChar());

			my $newFormationFile = Formation::writeFile($univ, $dateFile, $tmpRep);
			my $prefixFile;

			DiffCsv::trieFile($newFormationFile, $tmpRep, $resRep, 1 );

			if ($lastPath) {
				compareSortedFile($newFormationFile, $resRep, $lastPath,  1) or next TRAITEMENT;
			}
			
			for (Traitement::parseFile('ETU', $univ ,  $dateFile, $annee, $tmpRep)) {
				DiffCsv::trieFile($_, $tmpRep, $resRep, 3, 3);
				if ($lastPath) {
					compareSortedFile($_, $resRep, $lastPath,  3, 3) or next TRAITEMENT;
				}
			}

			for (Traitement::parseFile('STAFF', $univ ,  $dateFile, $annee, $tmpRep)) {
				DiffCsv::trieFile($_, $tmpRep, $resRep, 3, 2);
				if ($lastPath) {
					compareSortedFile($_, $resRep, $lastPath,  3, 2) or next TRAITEMENT;
				}
			}

			if ($lastPath) {
				#on parcourt l'ancien repertoire pour voir si l'on n'a pas des fichiers absents dans le nouveau.
				opendir OLDREP, $lastPath;
				while (readdir OLDREP) {
					my $oldFile = $_;
					if (s/_\d{8}.csv$//) {
						unless ($allNewPrefixFile{$_}) {
							INFO!  "nouveau fichier inexistant ! l'ancien étant : $oldFile\n";
							my $newFile = $oldFile;
							$newFile =~ s/.csv$/.supp.csv/;
							copy $lastPath . $oldFile, $resRep . $newFile;
						}
					}
				}
			}

			#on creer le fichier SQL;
			Traitement::writeAjoutSql("${workingDir}/${relativePath}${outSuffix}modifMail.sql");
			
			my $zipName = lc($relativePath). '.kapc.1.3.zip';

			SYSTEM! ("cd $workingDir; /usr/bin/zip -qq -r ${zipName} ${relativePath} ${relativePath}${outSuffix} ${relativePath}.log");

			#on memorise le new path
			$dataProps->changeProperty($univ->id(),$newPath);
			DEBUG! $univ->id, " <=", $newPath;

			
		}
	} else {
		ERROR! $univ->id(), " KO; newPath=$newPath; workinDir=$workingDir";
	}
}



# on ecrit le dataFile
open my $data, ">$dataFile" or FATAL! "error ecriture $dataFile: $!";
$dataProps->save($data);


sub compareSortedFile {
	my $fileName = shift;
	my $newRep = shift;
	my $lastRep = shift;
	my $enteteSize = shift;
	my @cle = @_;

	unless ($lastRep =~ /(_\d{8})/ ) {
		ERROR! "Comparaison impossible: Ancien repertoire non daté: $lastRep";
		return 0;
	}
	my $lastDate = $1;
	my $prefixFile = $fileName;
	unless ($prefixFile =~ s/_\d{8}.csv$//) {
		ERROR! "Comparaison impossible: Mauvais format de fichier: $fileName";
		return 0;
	};

	my $oldFile = $lastRep . $prefixFile . $lastDate . ".csv";
	my $newFile = my $addFile = my $suppFile = my $diffFile = $newRep . $fileName;

	$addFile =~ s/_\d{8}.csv$/$lastDate.add.csv/;
	$suppFile =~ s/_\d{8}.csv$/$lastDate.supp.csv/;
	$diffFile =~ s/_\d{8}.csv$/$lastDate.diff.csv/;
	
	if ( -f $oldFile) {
		DEBUG! "openAndCompareFile($oldFile, $newFile, $addFile, $suppFile, $diffFile, $enteteSize ..)";
		DiffCsv::openAndCompareFile($oldFile, $newFile, $addFile, $suppFile, $diffFile, $enteteSize, @cle);
	} else {
		# l'ancien fichier n'existe pas => le nouveau n'est qu'ajouts;
		INFO! "Comparaison ($fileName): Ancien fichier inexistant: $oldFile";

		copy $newFile, $addFile;
	}
	$allNewPrefixFile{$prefixFile} = $fileName;
	return  1;
}

=begin
	Recherche du fichier FORMATION en deduit le préfix et la date.
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
	ERROR!  "fichier des formations non trouvé dans :$rep\n";
	closedir REP;
	return 0;
}
