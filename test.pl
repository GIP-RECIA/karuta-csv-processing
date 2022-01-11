#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use univ;
use download;
use formation;
use traitementCsv;

my $pathRep = 'Test';

my $univ = new Univ('tours', 'univ.tours', 'Test', 'univ-Tours');
$univ = new Univ('orleans', 'univ.orleans', 'Test', 'univ-Orleans');
 # $univ->sepChar(',');

#goto SUITE;
my $ftp = '/usr/bin/sftp -b- rca_masterent@pinson.giprecia.net';  

Download::openFtp($ftp);

#foreach my $file (Download::ftpRead('univ.tours')) {
#	print "$file \n";
#}

foreach my $univ (Univ::all) {
	my $newPath = Download::initRepZip($univ->path, $univ->ftpRep);
	if ($newPath) {
		$univ->path($newPath);
		print ("new path = " . $univ->path() . "\n");
	} else {
		# on vide le path pour indiqué qu'il n'y a pas de nouveau fichiers
		$univ->path("");
	}
}

Download::closeFtp();
#SUITE:
#$univ->path('Test/Orleans_20220107');
foreach my $univ (Univ::all) {
	my $newPath = $univ->path();
	if ($newPath) {
		my ($formationFile, $prefixFile, $dateFile) = findInfoFile($newPath);
		if ($formationFile) {
			Formation::readFile($newPath, $formationFile, $univ->sepChar());
			Traitement::parseFile('ETU', $univ ,  $dateFile, '2021');
			Traitement::parseFile('STAFF', $univ ,  $dateFile, '2021');
			system ("/usr/bin/zip -r ${newPath}.zip ${newPath}*");
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
	print "fichier des formation non trouvé $rep\n";
	closedir REP;
	return 0;
}

__END__

$univ->prefix('univ-Tours');
$univ->path('Test/Tours_20220107');

Traitement::parseFile('ETU', $univ ,  '2022-01-07', '2021');

#Download::initRepZip('Test', 'univ.tours');
#Download::initRepZip('Test', 'univ.orleans');

Formation::readFile("Test/univ-tours/univ-tours_2021-12-07_formations.csv");

Traitement::parseFile('ETU', $univ ,  '2021-12-07', '2021');
Traitement::parseFile('STAFF', $univ ,  '2021-12-07', '2021');
