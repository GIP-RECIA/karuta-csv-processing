use strict;
use utf8;
use Dao;
use Formation;
use MyLogger ;# 'DEBUG';
#use Filter::sh "tee " . __FILE__ . ".pl";

#########
#
#
§package Personne;

§PARAM info;
§PARAM id;
§PARAM nom;
§PARAM prenom;
§PARAM univ;
§PARAM courriel;
§PARAM matricule;

use Hash::Util::FieldHash;

Hash::Util::FieldHash::fieldhash my %Compteurs;
Hash::Util::FieldHash::fieldhash my %CodeEtapes;

sub new {
	my §NEW;
	my $id = shift;
	my @info = @_;
	if (testInfo($id, @info)) {
		$Compteurs{$self} = {};
		§info =  \@info;
		§id = $id;
		return $self;
	}
	return 0;
}

sub compteur {
	my ($self, $key) = @_;
	return $Compteurs{$self}->{$key}++;
}
sub inFile {
	return &compteur;
}

sub testInfo {
	# le 1er champ eppn
	foreach my $col (@_) {
		if ($col =~ m/^\s*$/) {
			return 0;
		}
	}
	return $_[0] =~ m/^(\w|\.|\@|\-)+$/;
}

sub setCodesEtape {
	my $self = shift;
	my $univ = shift;
	my @codesEtape;
	my $filtre = $univ->filtreEtap;

	if (@_ > 1 ) {
		@codesEtape = map ({s/\s*(\S+)\s*/$1/; $_} @_);
		if ($filtre) {
			@codesEtape = &$filtre(@codesEtape);
		}
	} else {
		 chomp($_[0]);
		 @codesEtape =split ('@', $_[0]);
		 if ($filtre) {
			 @codesEtape = &$filtre(@codesEtape);
		 } 
	}
	# on supprime le codeEtap inexistant 
	@codesEtape = grep(Etape::byCode($_), @codesEtape);

#	$$self{codesEtape} = \@codesEtape;
	$CodeEtapes{$self} = \@codesEtape;
	return @codesEtape;
}

sub codesEtape {
#	return $self->{codesEtape};
	return $CodeEtapes{shift()}
}

sub type {
	return 0;
}

sub getEntete {
	my $class = shift;
	my $type = shift;

	if ($type eq 'ETU') {
		return Etudiant->entete(@_);
	}
	return Staff->entete(@_);
}




###############
#
#
package Etudiant;
use base qw(Personne);


sub entete {
	my $class = shift;
	my $univ = shift;
	my $annee = shift;
	my $etape = shift;
	my $typeFile = shift;
#	my $site = $etape->site;
	my $formation = $etape->formation;
	my $formation_label = $formation->formationLabel;
	my $formation_code = $formation->formationCode;

	my $cohorte = $etape->cohorte; 

#	my $cohorte = $etape->cohorte;
	
	return (
		["model_code","formation_code", "formation_label", "cohorte",""],
		[	"kapc/8etudiants.batch-creer-etudiants-authentification-externe",
			"${formation_code}",
			"${formation_label}",
			"${cohorte}",""
		],
		["nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","matriculeEtudiant", "loginEtudiant"]
	)
}

sub create {
	my $class = shift;
	my $univ = shift;
		# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $matricule = shift;
		# identifiant + liste des infos en sortie dans csv

	my $self = new ($class , $univ ,$eppn, $nom ,$prenom , $courriel , $matricule); 

	if ($self) {
		# on cree en base la personne que si il a des code étape, apres filtrage
		# si la personne existe déjà on la remet pour cette version:
		
		my @codeEtapesFiltres = $self->setCodesEtape($univ, @_);
		if (@codeEtapesFiltres || ! Dao->dao->isNewPersonne($eppn, type())) {
			
			Dao->dao->addPerson(type(), $eppn, $nom, $prenom, $courriel, $matricule);

			my $nbEtap;
			foreach my $code (@codeEtapesFiltres) {
				Dao->dao->addPersonneEtap($eppn, $code, type(), ++$nbEtap);
			}
			return $self;
		} 
		#§DEBUG 'pas de code etape apres  filtrage ', @_;
	}
	return 0;
}

sub new {
	my $class = shift;
	my $univ = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $matricule = shift;
	my $self = Personne::new($class, $eppn, $nom, $prenom, $courriel, $matricule, $eppn);
	if ($self) {
		§univ = $univ;
		§nom = $nom;
		§prenom = $prenom;
		§courriel = $courriel;
		§matricule = $matricule;
		return  $self;
	}
	return 0;
}

sub type {
	return 'ETU';
}



###############
#
#
package Staff;
use base qw(Personne);

sub entete {
	my $class = shift;
	my $univ = shift;
	my $annee = shift;  # attention $annee et $etap ne sont pas utilisé mais sont transmise
	my $etape = shift;
	my $typeFile = shift; # 2 typeFile  ... et Formation
	if ($typeFile eq 'Formation') {
		return (
			[ "model_code","","",""],
			[ "kapc/7enseignants.batch-associer-enseignants-formations","","",""],
			[ "nomFamilleEnseignant","prenomEnseignant","loginEnseignant","formation_code"]
		)
	} else {
		return (
			["model_code","","",""],
			["kapc/7enseignants.batch-creer-enseignants-authentification-externe","","",""],
			["nomFamilleEnseignant","prenomEnseignant","loginEnseignant","courrielEnseignant"]
		)
	}
}

sub create {
	my $class = shift;
	my $univ = shift;
			# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
		# identifiant + liste des infos en sortie dans csv
	my $self = new ($class,  $univ, $eppn, $nom, $prenom, $courriel);
	
	if ($self) {
		# on cree en base la personne que si il a des codes étapes, apres filtrage
		# ou qu'il existe déjà
		my @codeEtapesFiltres = $self->setCodesEtape($univ, @_);
		
		if (@codeEtapesFiltres || ! Dao->dao->isNewPersonne($eppn, type())) {
			Dao->dao->addPerson(type(), $eppn, $nom, $prenom, $courriel, "");
			my $nbEtap;
			foreach my $code (@codeEtapesFiltres) {
				Dao->dao->addPersonneEtap($eppn, $code, type(), ++$nbEtap);
			}
			return $self;
		}
	}
	return 0;
}

sub new {
	my $class = shift;
	my $univ = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $self = Personne::new($class, $eppn, $nom, $prenom, $eppn, $courriel);
	if ($self) {
		§univ = $univ;
		§nom = $nom;
		§prenom = $prenom;
		§courriel = $courriel;
		return $self;
	}
	return 0;
}

sub type {
	return 'STAFF';
}

##############
#
# SUPERVISEUR
#
package Superviseur;
use base qw(Personne);

sub new {
	my $class = shift;
			# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $self = Personne::new($class, $eppn, $nom, $prenom, $courriel);

	if ($self) {
		§nom = $nom;
		§prenom = $prenom;
		return  $self;
	}
}
sub type {
	return 'SUPERVISEUR';
}

1;
