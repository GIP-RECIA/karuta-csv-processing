#!/usr/bin/perl
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;
use Dao;
use Univ;
use Data::Dumper;
use MyLogger;


MyLogger->file('> test.log');

MyLogger::level(2 , 1);

# MyLogger::file 'workIn.log';
INFO! "test de info";
 DEBUG! "le debug";
 WARN! "une alerte", " avec plusieurs param";
# ERROR! "une erreur";

my $pathRep = 'Test';

SYSTEM!("ls -l");
#SYSTEM!("rm -v Test/Orleans_20220107*");
SYSTEM!("ls -l Test");

my $univ = new Univ('orleans', 'noFtp', 'testOrleans/', 'orleans');

sub testDao {
	print "debut test dao \n";

	my $dao = new Dao("test.db", $univ, "20230919");

	WARN! 'lastVersion = ', $dao->lastVersion();
	$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '123');
	$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '1234');

	$dao->addFormation('codeF1', 'site1', 'formation11');
	$dao->addEtape('etap1', 'libetap1', 'codeF1', 'site1');
	
	 $dao = new Dao("test.db", $univ, "20231010");
	 $dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '123');
	$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '1234');

	$dao->addFormation('codeF1', 'site1', 'formation11');
	$dao->addEtape('etap1', 'libetap1', 'codeF1', 'site1');
	WARN! 'lastVersion = ', $dao->lastVersion();
}

&testDao();

sub testUniv {
	print "Test univ\n";
	
	print Dumper($univ);
	my $testEtap = Univ->getById('orleans')->testEtap;
	if ($testEtap) {
		my $etap = 'abcIde';
		print $etap, "\n";
		print &$testEtap($etap)? 'TRUE' : 'FALSE'  , " $etap\n";
		$etap = 'abcFde';
		print $etap, "\n";
		print &$testEtap($etap) ? 'TRUE' : 'FALSE' , " $etap\n";
	} else {
		ERROR! "pas de testEtap!";
	}

	my $filtreEtap = Univ->getById('orleans')->filtreEtap;
	if ($filtreEtap) {
		print "test filtreEtap\navant: ";
		my @etap = qw/abcIde fgfFhij abcAde  fgfIhij/;
		print Dumper(@etap);
		print "apres: ";
		print Dumper(&$filtreEtap(@etap));
	} else {
		ERROR! "pas de filtreEtap!";
	}

	$univ = new Univ('tours', 'noFtp', 'testTours/', 'tours');
	$filtreEtap = $univ->filtreEtap;
	$testEtap = $univ->testEtap;
	if ($testEtap) {
		my $etap = 'abcIde';
		print $etap, "\n";
		print &$testEtap($etap)? 'TRUE' : 'FALSE'  , " $etap\n";
		$etap = 'abcFde';
		print $etap, "\n";
		print &$testEtap($etap) ? 'TRUE' : 'FALSE' , " $etap\n";
	} else {
		ERROR! "pas de testEtap pour tours!";
	}
	if ($filtreEtap) {
		print "test filtreEtap\navant: ";
		my @etap = qw/abcIde fgfFhij abcAde  fgfIhij/;
		print Dumper(@etap);
		print "apres: ";
		print Dumper(&$filtreEtap(@etap));
	} else {
		ERROR! "pas de filtreEtap pour tours!";
	}
}
