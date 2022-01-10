#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use univ;
use download;
use formation;
use traitementCsv;

new Univ('tours', 'univ.tours', 'Test', 'univ-tours');
new Univ('orleans', 'univ.orleans', 'Test', 'univ-Orleans');

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
	}
}

Download::closeFtp();

#Download::initRepZip('Test', 'univ.tours');
#Download::initRepZip('Test', 'univ.orleans');
__END__

Formation::readFile("Test/univ-tours/univ-tours_2021-12-07_formations.csv");

Traitement::parseFile('ETU', $univ ,  '2021-12-07', '2021');
Traitement::parseFile('STAFF', $univ ,  '2021-12-07', '2021');
