#!/usr/bin/perl -w
use Test::Simple tests => 23;
#use  Try::Tiny;
use utf8;
use Cwd;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;
use Dao;
use Univ;
use Data::Dumper;
use MyLogger;


#MyLogger->file('> test.log');
MyLogger::level(2 , 0);

my $pathRep = 'Test';

#SYSTEM!("ls -l");
#SYSTEM!("rm -v Test/Orleans_20220107*");
#SYSTEM!("ls -l Test");

my $univ = new Univ('orleans', 'noFtp', 'testOrleans/', 'orleans');
ok($univ, 'new Univ');

my $test = '';


my $testDb = 'test.db';

unlink $testDb;

&testDao();
&testGlobal();

sub testDao {
	
	my $dao = Dao->create($testDb, $univ, "20230919");
	ok($dao, "create dao");


	$test = eval $dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '123');
	ok(!$@  && $test, 'add new person');

	eval { $test = $dao->getPersonne('eppn1', 'ETU') };
	ok(!$@ && $test->isa(Etudiant), "getPersonne etudiant ");

	$test = eval $dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '1234');
	ok(!$@ && !$test, 'add old person with different matricule');

	eval { $test = $dao->getPersonne('eppn1', 'ETU') };
	ok(!$@ && $test->matricule() eq '123', 'get old personne' );

	$test = eval $dao->addFormation('codeF1', 'site1', 'formation11');
	ok(!$@ && $test, "addFormation $@ $test ");

#	ok(!$@ && !$test, "addFormation $@ :" . $test ? '' : $dao->errStr);

	$test = eval {$dao->addEtape('etap1', 'libetap1', 'codeF1', 'site1')};

	ok(!$@ && $test, "addEtape $@");

	$dao = Dao->create($testDb, $univ, "20231010");
	ok($dao, "create new dao");
	$dao->addPerson('ETU', 'eppn1', 'Cunafo', 'Didier', 'didier.cunafo', '1234');
	ok(!$@ && $test, 'new dao add person  ');

	eval { $test = $dao->getPersonne('eppn1', 'ETU') };
	ok(!$@ && $test->matricule() eq '1234', 'get  personne' );

	$dao->addFormation('codeF1', 'site1', 'formation11');
	$dao->addEtape('etap1', 'libetap1', 'codeF1', 'site1');
	$dao->addEtape('etap2', 'libetap2', 'codeF1', 'site1');
	
	$dao->addPersonneEtap('eppn1', 'etap1', 'ETU', 1);
	$dao->addPersonneEtap('eppn1', 'etap2', 'ETU', 2);

	eval{ $test = $dao->getEtapeEtu('eppn1')};
	ok(!$@ && $test && ($test->code() eq 'etap1'), "getEtapeEtu 1 $@" );

	eval {$test = $dao->getEtapeEtu('eppn1', 2, '20231010') ;};
	ok(!$@ && $test && ($test->code() eq 'etap2'), "getEtapeEtu 2 $@" );

	
	
	eval {
		$dao->getEtapeEtu( 'eppn1', 1, '20230919');
	} ;
	ok($@ , "getEtapeEtu 3" );
	
	
	ok($dao->lastVersion(), 'read not init last version ');
	ok($dao->lastVersion() eq '20230919', 'last version = 20230919');

	ok($dao->lastVersion("20231010"), 'init last version 20231010');
	ok($dao->lastVersion() eq '20231010', 'lire last version 20231010');
	ok(!$dao->lastVersion("20231011"), 'init last version 20231011');

}

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

sub testGlobal {
	my $repAbs = getcwd();
	my $repTest = 'Test';
	
	my $repOrg = $repTest . '/Org';
	my $repNew = $repTest . '/New';
	if (-d $repNew) {
		SYSTEM! "rm -r $repNew";
	}
	
	SYSTEM! "cp -R $repOrg $repNew";
	SYSTEM! "rm -R $repNew/*_*_*";
	SYSTEM! "cp $repTest/karuta.properties $repNew";

	SYSTEM! "./workIn.pl $repNew";
	
	mkdir "$repNew/orleans_20230322_trie";
	mkdir "$repNew/Tours_20231005_trie";

	chdir $repNew . "/Tours_20231005_kapc.1.3.5";
	SYSTEM! 'for i in *; do  sort $i > ../Tours_20231005_trie/$i ; done';
	
	chdir "$repAbs/$repNew/orleans_20230322_kapc.1.3.5";
	SYSTEM! 'for i in *; do sort $i > ../orleans_20230322_trie/$i ; done';

	chdir "$repAbs/$repTest";
	system 'diff Org/orleans_20230322_trie/ New/orleans_20230322_trie/ > diff.test';
	ok (-z 'diff.test', 'orleans_20230322');
	system 'diff Org/Tours_20231005_trie/ New/Tours_20231005_trie/ > diff.test';
	ok (-z 'diff.test', 'Tours_20231005');

	chdir "$repAbs/$repTest";
	open PIN, "karuta.properties" or FATAL! "$!";
	open POUT, ">New/karuta.properties" or FATAL! "$!";
	while (<PIN>) {
		next if /^\w+\.test\.newPath/;
		s/^\#(\w+\.test\.newPath)/$1/;
		print POUT ;
	}
	close PIN;
	close POUT;

	chdir "$repAbs";
	SYSTEM! "./workIn.pl $repNew";
	
	chdir $repNew . "/Tours_20231120_kapc.1.3.5";
	SYSTEM! 'for i in *; do  sort $i > ../Tours_20231120_trie/$i ; done';
	
	chdir "$repAbs/$repNew/orleans_20231024_kapc.1.3.5";
	SYSTEM! 'for i in *; do sort $i > ../orleans_20231024_trie/$i ; done';
	chdir "$repAbs/$repTest";
	system 'diff Org/orleans_20231024_trie/ New/orleans_20231024_trie/ > diff.test';
	ok (-z 'diff.test', 'orleans_20231024');
	system 'diff Org/Tours_20231120_trie/ New/Tours_20231120_trie/ > diff.test';
	ok (-z 'diff.test', 'Tours_20231120');
}
