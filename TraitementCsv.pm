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
my %ListeETU;
my %oldMailETU;

sub parseFile {
	my $class = shift;
	$type = shift;
	$univ = shift;
	$dateFile = shift;
	$annee = shift;
	$tmp = shift; #le repertoire temporaire de travail;

	%fileName2file =();
	%StaffFiles = ();
	

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
	my $traitement;
	if ($isEtu = $type eq 'ETU') {
		%ListeETU = ();
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
				unless ($etape) {
					WARN! ("pas d'etape pour ce codeEtap : $codeEtap !");
					print LOG $personne->{id} . ": codeEtape erreur: $codeEtap !\n";
					next;
				}
				my @info = @{$personne->info};
				my $formationLabel = $etape->formation->code;
				unless ($personne->compteur($formationLabel)) {
					@info[3]= $formationLabel;
					DEBUG! @info;
					$csv->print($file, \@info);
					print $file  "\n";
				}
			}
		}
	}
	return 0;
}



sub mailEtu2sql {
	my $class = shift;
	my $newPath = shift;
	my $suffixPath = shift;
	my $oldPath = shift;
	

	my $fileMail = "allMail.txt";
	my $modifMailFile = $newPath . $suffixPath. "modifMail.sql";
	my $addEppnFile = $newPath . $suffixPath. "addEppn.sql";
	my $newMailFile = $newPath . $suffixPath. $fileMail;
	my $oldMailFile = $oldPath . $fileMail;

	DEBUG! "modifMailFile = $modifMailFile ; newMailFile = $newMailFile ; oldMailFile = $oldMailFile.";

	open SQLMAIL, "> $modifMailFile" or FATAL! "open $modifMailFile : $!";
	open SQLEPPN, "> $addEppnFile" or FATAL! "open $addEppnFile : $!";
	open NEWMAIL, "> $newMailFile" or FATAL! "open $newMailFile : $!";
	
	
	if ($oldPath) {
		%oldMailETU=();
		open OLDMAIL, $oldMailFile or FATAL! "open $oldMailFile : $!";
		while (<OLDMAIL>) {
			my ($eppn, $mail) = split;
			if ($eppn) {
				$oldMailETU{$eppn} = $mail;
			}
		}
		close OLDMAIL;
	} else {
		DEBUG! "oldPath est vide";
	}

	
	foreach my $etu (values %ListeETU) {
		my $eppn = $etu->{id};
		my $mail = $etu->{mail};

		DEBUG! "etu : $eppn\t$mail";
		
		my $isNew = 1;
		if ($oldPath) {
			my $oldMail = $oldMailETU{$eppn};
			if ($oldMail) {
				$isNew = 0;
				if ($oldMail ne $mail) {
					print SQLMAIL qq/update credential set email="$mail" where eppn="$eppn";/, "\n";
				}
			}
		}
		if ($isNew) {
			print SQLEPPN qq/update credential set eppn="$eppn" where login = "$mail";/, "\n";	
		}
		print NEWMAIL "$eppn\t$mail\n";
	}
	close SQLMAIL;
	close NEWMAIL;
}

sub printInFormationFileETU {
	my $etape = shift;
	my $personne = shift;
	my $file  = getFileETU($etape);
	if ($file) {
		unless ($personne->inFile($file) ) {
			$csv->print($file, $personne->info());
			print $file  "\n";
			# verru pour le changement de mail
			$ListeETU{$personne->{id}} = $personne;
			DEBUG! "ListeETU add " . $personne->{id};
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

DEBUG! "openfile " . Dumper($etape);
		foreach my $entete (Personne->getEntete($type, $univ->id, $annee, $etape, $typeFile)) {
			my $finDeLigne = @$entete > 1 ? "\n" : ",\n";
			$csv->print($file, $entete);
			print $file $finDeLigne;
		}

		$fileName2file{$fileName} = $file;
		return $file;
	}
	return 0;
}


sub getFileSTAFF {
	my $typeFile =  shift; # Formation ou autre
	my $file;

	$file = $StaffFiles{$typeFile};
	unless ($file) {
		$file = openFile($typeFile, 'STAFF' , "");
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
	my $formation = $etape->formation;
	
	$haveFiles = $etape;
	$typeFile = $etape->site . "_" . $etape->cohorte;
#	$typeFile = $etape->cohorte;
	
	$haveFiles->getFile('ETU');
	
	unless ($file) {
		$file = openFile($typeFile, 'ETU' , $etape);
		if ($file) {
			$haveFiles->setFile($file, 'ETU');
		}
	}
	return $file;
}

1;
