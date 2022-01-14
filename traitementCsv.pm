use strict;
use utf8;
use Text::CSV; # sudo apt-get install libtext-csv-perl
use open qw( :encoding(utf8) :std );
use IO::File;

use FindBin;                    # ou est mon executable
use lib $FindBin::Bin;  		# chercher les libs au meme endroit

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
	my $fileName = sprintf("%s_%s_%s.csv", $univ->prefix, $dateFile, $type); 
	$path = $univ->path;
	$tmp = "${path}_tmp";

	 #$csv->sep_char($univ->sepChar());
	 DEBUG "open $path/$fileName \n";
	open (CSV, "<$path/$fileName") || FATAL "$path/$fileName  " . $!;

	unless ( -d $tmp) {
		mkdir $tmp, 0775;
	}
	my $isEtu = $type eq 'ETU';
	$_ = <CSV>;
	while (<CSV>) {
		s/\"\;\"/\"\,\"/g; # on force les ,
		if ($csv->parse($_) ){
			# "eppn";"nomFamilleEtudiant";"prenomEtudiant";"courrielEtudiant";"matriculeEtudiant";"codesEtape"...
			
			my $person;
			if ($isEtu) {
				$person = new Etudiant($csv->fields());
			} else {
				$person = new Staff($csv->fields());
			}
			traitement($person);
		}
	}
	foreach my $file (values %fileName2file) {
		close $file;
	}
	%fileName2file =();
}

sub traitement {
	my $personne = shift;
	foreach my $code (@{$personne->codesEtape()}) {
		my $formation = Formation::get($code);
		if ($formation) {
			printInFormationFile($formation, $personne);
		} else {
			warn ("pas de formation pour ce codeEtap : $code ! \n");
		}
	}
}
sub printInFormationFile {
	my $formation = shift;
	my $personne = shift;
	my $file = getFile($formation, $personne->type);
	if ($file) {
		$csv->print($file, $personne->info());
		print $file  "\n";
	}
}



sub openFile {
	my $formation = shift;
	my $type = shift;
	if ($formation && $type) {
		
		my $cohorte = $formation->court();
	

		my $diplome = lc($formation->diplome());

		
		my $fileName = sprintf("%s_%s_%s_%s_%s_%s.csv", $univ->id , $diplome , $type, $cohorte, $annee, $dateFile);

		my $file = $fileName2file{$fileName};
		if ($file) {
			return $file;
		} else {
			$file = new IO::File;
		}

		DEBUG "write file  $fileName\n";

		open ($file , ">$tmp/$fileName") || FATAL "$tmp/$fileName " . $!;
		
		foreach my $entete (Personne->getEntete($type, $univ->id, $annee, $diplome, $cohorte)) {
			$csv->print($file, $entete);
			print $file "\n";
		}

		$fileName2file{$fileName} = $file;
		return $file;
	}
	return 0;
}

sub getFile {
	my $formation= shift;
	my $type = shift;
	
	my $file = $formation->getFile($type);
	unless ($file) {
		$file = openFile($formation, $type);
		if ($file) {
			$formation->setFile($file, $type);
		}
	}
	return $file;
}



1;
