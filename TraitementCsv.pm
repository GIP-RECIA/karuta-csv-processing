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
		s/,?\s*$//; # on suprime le dernier champs vide
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
		 WARN! "csv no parse line : ",  $fileName,"(",$nbligne,") : $_\n";
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
		my $etape = Etape::byCode($codeEtap);
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
			$csv->say($file, $personne->info);
		}
		$file = getFileSTAFF('Formation');
		if ($file) {
			foreach my $codeEtap (@{$personne->codesEtape()}) {
				my $etape = Etape::byCode($codeEtap);
				my @info = @{$personne->info};
				my $formationLabel = $univ->id . "_". $etape->site . "_". $etape->formation->code;
				unless ($personne->compteur($formationLabel)) {
					@info[3]= $formationLabel;
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
			$csv->say($file, $personne->info);
		}
	}
}

sub printAddEtapFileETU {
	my $etape = shift;
	my $personne = shift;
	
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
		$etape = Etape::byCode($etape);
	}
	my $univId = $etape->univId;
	
	my $formation = $etape->formation;
	
	
	$haveFiles = $etape;
	$typeFile = $etape->cohorte ;
	$typeFile =~ s/${univId}_//g; #on enleve l'univ de la cohorte
	
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

########## les ajouts pour les diffs :


sub getFileAddEtapETU {
	my $etapeOrg = shift;
	my $etapeAdd = shift;

	my $fileName = sprintf("ajouter_%s_%s_%s_%s_%s.csv", $etapeOrg->cohorte, $etapeOrg->formation->code, $etapeAdd->lib, $annee, $dateFile);
	
	my $file = $fileName2file{$fileName};
	if ($file) {
		return $file;
	}
	open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
	$csv->say($file, ['model_code','formationOriginale_code', 'cohorteOriginale', 'formationSupplementaire_code']);
	$csv->say($file, ['kapc/8etudiants.batch-ajouter-etudiants-formation-supplementaire', $etapeOrg->formation->code, $etapeOrg->cohorte, $etapeAdd->formation->formationCode]);
	$csv->say($file, ['loginEtudiant']);

	$fileName2file{$fileName} = $file;
	return $file;
}

sub printAddEtapETU {
	my $idPersonne = shift;
	my $etapeOrg = shift;
	my $etapeAdd = shift;

	my $file = getFileAddEtapETU($etapeOrg, $etapeAdd, $idPersonne);

	$csv->say($file, [$idPersonne]);
	
}

sub getFileDelEtapETU {
	my $etapeOrg = shift;
	my $etapeDel = shift;

	
	my $fileName = sprintf("retirer_ETU_%s_%s_%s_%s_%s.csv", $etapeOrg->cohorte, $etapeOrg->formation->code, $etapeDel->lib, $annee, $dateFile);
	my $file = $fileName2file{$fileName};
	if ($file) {
		return $file;
	}
	open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
	$csv->say($file, ['model_code','formationOriginale_code', 'cohorteOriginale', 'formationSupplementaire_code']);
	$csv->say($file, ['kapc/8etudiants.batch-retirer-etudiants-formation-supplementaire', $etapeOrg->formation->formationCode, $etapeOrg->cohorte, $etapeDel->formation->formationCode]);
	$csv->say($file, ['loginEtudiant']);

	$fileName2file{$fileName} = $file;
	return $file;
}
sub printDelEtapETU {
	my $idPersonne = shift;
	my $etapeOrg = shift;
	my $etapeDel = shift;

	my $file = getFileDelEtapETU($etapeOrg, $etapeDel, $idPersonne);

	$csv->say($file, [$idPersonne]);
}

sub getFileModifEtapETU {
	my $etapeOld = shift;
	my $etapeNew = shift;

	my $fileName = sprintf("changer_ETU_%s__%s_%s_%s.csv", $etapeOld->cohorte, $etapeNew->cohorte, $annee, $dateFile);
	
	my $file = $fileName2file{$fileName};
	if ($file) {
		return $file;
	}
	open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
	$csv->say($file, ['model_code','ancienneFormation_code', 'ancienneCohorte', 'nouvelleFormation_code','nouvelleFormation_label','nouvelleCohorte']);
	$csv->say($file, ['kapc/8etudiants.batch-changer-formation-etudiants', $etapeOld->formation->formationCode, $etapeOld->cohorte, $etapeNew->formation->formationCode, $etapeNew->formation->formationLabel, $etapeNew->cohorte]);
	$csv->say($file, ['nomFamilleEtudiant','prenomEtudiant','loginEtudiant']);

	$fileName2file{$fileName} = $file;
	return $file;
}

sub printDelEtapSTAFF {
	my $idPersonne = shift;
	my $etapeDel = shift;

	my $fileName = sprintf("retirer_STAFF_FORMATION_%s_%s.csv", $annee, $dateFile);
	my $file = $fileName2file{$fileName};
	unless ($file) {
		open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
		$csv->say($file, ['model_code','']);
		$csv->say($file, ['kapc/7enseignants.batch-retirer-enseignants-formations', '']);
		$csv->say($file, ['loginEnseignant', 'formation_code']);
		$fileName2file{$fileName} = $file;
	}
	$csv->say($file, [$idPersonne, $etapeDel->formation->formationCode]);
}

sub getFileDelETU {
	my $etapeOld = shift;
	my $fileName = sprintf("supprimer_ETU_%s_%s_%s.csv", $etapeOld->cohorte, $annee, $dateFile);
	my $file = $fileName2file{$fileName};
	if ($file) {
		return $file;
	}
	open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
	$csv->say($file, ['model_code','formation_code','cohorte']);
	$csv->say($file, ['kapc/8etudiants.batch-supprimer-etudiants', $etapeOld->formation->formationCode, $etapeOld->cohorte ]);
	$csv->say($file, [ 'loginEtudiant' ]);
	$fileName2file{$fileName} = $file;
	return $file;
}
sub printDelETU {
	my $idPersonne = shift;
	my $etapeOld = shift;

	my $file = getFileDelETU($etapeOld);
	$csv->say($file, [$idPersonne]);
}

sub printDelSTAFF {
	my $idPersonne = shift;
	my $fileName = sprintf("supprimer_STAFF_%s_%s.csv", $annee, $dateFile);
	my $file = $fileName2file{$fileName};
	unless ($file) {
		open ($file , ">$tmp/$fileName") || FATAL!  "$tmp/$fileName " . $!;
		$csv->say($file, ['model_code','Suppression enseignants']);
		$csv->say($file, ['kapc/7enseignants.batch-supprimer-enseignants', '' ]);
		$csv->say($file, [ 'loginEnseignant' ]);
		$fileName2file{$fileName} = $file;
	}
	$csv->say($file, [$idPersonne]);
}
my $etuCourant;

sub getEtu {
	my $idEtu = shift;
	unless ($etuCourant && $etuCourant->id eq $idEtu) {
		$etuCourant = Dao->dao->getPersonne($idEtu, 'ETU');
		FATAL! "etudiant introuvable " unless $etuCourant;
	}
	return $etuCourant;
}

sub printModifEtapETU {
	my $idEtu = shift;
	my $etapeOld = shift;
	my $etapeNew = shift;

	my $etu = getEtu($idEtu); 

	my $file = getFileModifEtapETU($etapeOld, $etapeNew);

	$csv->say($file, [$etu->nom, $etu->prenom, $idEtu]);
}

1;
