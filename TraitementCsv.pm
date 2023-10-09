use strict;
use utf8;
use Text::CSV; # sudo apt-get install libtext-csv-perl
use open qw( :encoding(utf8) :std );
use IO::File;

use formation;
use personne;
use MyLogger;


package TraitementCsv;
use Data::Dumper;

my %code2file;
my $csv = Text::CSV->new({ sep_char => ',', binary    => 1, auto_diag => 1, always_quote => 1});

my $univ ;
my $path ;
my $dateFile;
my $annee;
my $type;
my $tmp;
my %fileName2file;

my %StaffFiles;


sub init {
	$type = shift;
	$univ = shift;
	$dateFile = shift;
	$annee = shift;
	$tmp = shift; #le repertoire temporaire de travail;
	%fileName2file =();
	%StaffFiles = ();
	$path = $univ->path;
}

sub parseFile {
	init(@_);

	my $fileName = sprintf("%s_%s_%s.csv", $univ->prefix, $dateFile, $type);



	my $fileNameLog = "${path}.log";

	 #$csv->sep_char($univ->sepChar());
	 DEBUG! "open $path/$fileName \n";
	open (CSV, "<$path/$fileName") || FATAL!  "$path/$fileName  " . $!;
	open (LOG, ">>$fileNameLog");
	unless ( -d $tmp) {
		mkdir $tmp, 0775;
	}

	my $isEtu;
	my $traitement;
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
		s/,\s*$//; # on suprime le dernier champs vide
		if ($csv->parse($_) ){
			# "eppn";"nomFamilleEtudiant";"prenomEtudiant";"courrielEtudiant";"matriculeEtudiant";"codesEtape"...
			my $person;
			if ($isEtu) {
				$person = create Etudiant($univ, $csv->fields());
			} else {
				$person = create Staff($univ, $csv->fields());
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
			printInformationFileETU($etape, $personne);
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
	my $file = getFileSTAFF('Personne');
	if ($file) {
		unless ($personne->inFile($file) ) {
			$csv->print($file, $personne->info());
			print $file  "\n";
		}
		$file = getFileSTAFF('Formation');
		if ($file) {
			foreach my $codeEtap (@{$personne->codesEtape()}) {
				my $etape = Etape::getByCodeEtap($codeEtap);
				my @info = @{$personne->info};
				my $formationLabel = $univ->id . "_". $etape->site . "_". $etape->formation->code;
				unless ($personne->compteur($formationLabel)) {
					@info[3]= $formationLabel;
					DEBUG! map "$_, " ,@info;
					$csv->print($file, \@info);
					print $file  "\n";
				}
			}
		}
	}
	return 0;
}



sub printInformationFileETU {
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


sub openFile {
	my $typeFile = shift;
	my $type = shift;
	my $etape = shift; 
	
	if ($type) {
		
		my $fileName = sprintf("%s_%s_%s_%s_%s.csv", $univ->id , $type, $typeFile, $annee, $dateFile);


		my $file = $fileName2file{$fileName};
		if ($file) {
			return $file;
		} else {
			$file = new IO::File;
		}

		DEBUG! "write file  $fileName\n";

		open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;

		
		foreach my $entete (Personne->getEntete($type, $univ->id, $annee, $etape, $typeFile)) {
			my $finDeLigne = @$entete > 1 ? "\n" : ",\n";
			$csv->print($file, $entete);
			print $file $finDeLigne;
		}

		$fileName2file{$fileName} = $file;
		return ($file, $fileName);
	}
	return 0;
}


sub getFileSTAFF {
	my $typeFile =  shift; # Formation ou autre
	my $file;

	$file = $StaffFiles{$typeFile};
	my $fname;
	unless ($file) {
		($file, $fname) = openFile($typeFile, 'STAFF' , "");
		if ($file) {
			$StaffFiles{$typeFile} = $file;
		}
	}
	return $file;
}

sub getFileETU {
	my $etape = shift;
	my $file;
	my $haveFiles;
	my $typeFile; # contient  site_cohorte/formation .
	
	unless ($etape->isa('Etape') ) {
		$etape = Etape::getByCodeEtap($etape);
		DEBUG! Dumper($etape);
	}
	
	my $formation = $etape->formation;
	
	
	$haveFiles = $etape;
	$typeFile = $etape->cohorte;

	$haveFiles->getFile('ETU');

	my $fname;
	unless ($file) {
		($file , $fname) = openFile($typeFile, 'ETU' , $etape);
		if ($file) {
			Dao->dao->updateCohorte($etape->{'etap'}, $fname);
			$haveFiles->setFile($file, 'ETU');
		}
	}
	return $file;
}

1;
