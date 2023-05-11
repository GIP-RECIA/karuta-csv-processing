use strict;
use utf8;
use Text::CSV; # sudo apt-get install libtext-csv-perl
use open qw( :encoding(utf8) :std );
use IO::File;

use formation;
use personne;
use MyLogger;

package Traitement;


my %code2file;
my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 1, always_quote => 1});

my $univ ;
my $path ;
my $dateFile;
my $annee;
my $type;
my $tmp;
my %fileName2file;

sub parseFile {
	$type = shift;
	$univ = shift;
	$dateFile = shift;
	$annee = shift;
	$tmp = shift; #le repertoire temporaire de travail;

	%fileName2file =();

	my $fileName = sprintf("%s_%s_%s.csv", $univ->prefix, $dateFile, $type);
	
	$path = $univ->path;

	my $fileNameLog = "${path}.log";
	
	 #$csv->sep_char($univ->sepChar());
	 DEBUG! "open $path/$fileName \n";
	open (CSV, "<$path/$fileName") || FATAL!  "$path/$fileName  " . $!;
	open (LOG, ">>$fileNameLog");
	unless ( -d $tmp) {
		mkdir $tmp, 0775;
	}

	my $isEtu;
	my $straitement;
	if ($isEtu = $type eq 'ETU') {
		$traitement = \&traitementETU;
	} else {
		$traitement = \&traitementSTAFF;
	}

	$_ = <CSV>;
	my $nbligne = 1;
	while (<CSV>) {
		$nbligne ++;
		s/\"\;\"/\"\,\"/g; # on force les ,
		if ($csv->parse($_) ){
			# "eppn";"nomFamilleEtudiant";"prenomEtudiant";"courrielEtudiant";"matriculeEtudiant";"codesEtape"...
			my $person;
			if ($isEtu) {
				$person = new Etudiant($univ, $csv->fields());
			} else {
				$person = new Staff($univ, $csv->fields());
			}
			if ($person) {
				if (&$traitement($person)) {
					print LOG "dans $fileName ligne $nbligne\n";
				}
			} else {
				print LOG "$fileName rejet : $_\n";
			}
		} else {
			DEBUG! "csv no parse line : ", $nbligne, " $fileName: $_\n";
		}
	}
	foreach my $file (values %fileName2file) {
		close $file;
	}
	
	close LOG;
	return keys %fileName2file;
}


sub traitementETU {
	my $personne = shift;
	my $nberr = 0;
	foreach my $codeEtap (@{$personne->codesEtape()}) {
		my $etape = Etape::getByCodeEtap($codeEtap);
		if ($etape) {
			printInFormationFileETU($etape, $personne);
		} else {
			WARN! ("pas d'etape pour ce codeEtap : $codeEtap !");
			print LOG "codeEtape erreur: $codeEtap !\n";
			$nberr++;
		}
	}
	return $nberr;
}

sub traitementSTAFF {
	my $personne = shift;
	my $nberr = 0;
	#TODO le reste du traitement
}



sub printInFormationFileETU {
	my $etape = shift;
	my $personne = shift;
	my $file  = getFileETU($etape);
	if ($file) {
		unless ($personne->inFile($file) ) {
			$csv->print($file, $personne->info());
			print $file  "\n";
		}
	}
}



sub openFileETU {
	my $typeFile = shift; # pour les staff ce sera  formation_code 
	my $etape = shift;
	if ($etape) {
		
		my $fileName = sprintf("%s_%s_%s_%s_%s.csv", $univ->id , 'ETU', $typeFile, $annee, $dateFile);


		my $file = $fileName2file{$fileName};
		if ($file) {
			return $file;
		} else {
			$file = new IO::File;
		}

		DEBUG! "write file  $fileName\n";

		open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
		
		foreach my $entete (Personne->getEntete('ETU', $univ->id, $annee, $etape, $typeFile)) {
			$csv->print($file, $entete);
			print $file "\n";
		}

		$fileName2file{$fileName} = $file;
		return $file;
	}
	return 0;
}

sub getFileETU {
	my $etape = shift;
	my $file;
	my $haveFiles;
	my $typeFile; # contient  site_cohorte/formation .
	my $formation = $etape->formation;
	
	$haveFiles = $etape;
	$typeFile = $etape->site . "_" . $etape->cohorte;

	$haveFiles->getFile('ETU');
	
	unless ($file) {
		$file = openFileETU($typeFile, $etape);
		if ($file) {
			$haveFiles->setFile($file, 'ETU');
		}
	}
	return $file;
}

1;
