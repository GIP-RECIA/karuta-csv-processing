use strict;
use utf8;
use MyLogger;
use Dao;
use Data::Dumper;
#########
#
#
package Personne;

sub new {
	my $class = shift;
	my $id = shift;
	my @info = @_;
	if (testInfo($id, @info)) {
		my $self = {
			id => $id,
			info => \@info,
			compteurs => {}
		};
		return bless $self, $class;
	}
	return 0;
}

sub compteur {
	my ($self, $key) = @_;
	return $self->{compteurs}->{$key}++;
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
	my $filtre = $univ->{filtreEtap};

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

	$$self{codesEtape} = \@codesEtape;
	return @codesEtape;
}

sub codesEtape {
	my $self = shift;
	return $self->{codesEtape};
}

sub info {
	my $self = shift;
	return $self->{info};
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
use Data::Dumper;

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
	
	DEBUG! Dumper($etape);
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
		Dao->dao->addPerson(type(), $eppn, $nom, $prenom, $courriel, $matricule);
		my $nbEtap;
		foreach my $code ($self->setCodesEtape($univ, @_)) {
			Dao->dao->addPersonneEtap($eppn, $code, type(), ++$nbEtap);
		}
		return $self;
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
		$self->{univ} = $univ;
		$self->{NOM} = $nom;
		$self->{PRENOM} = $prenom;
		return  $self;
	}
	return 0;
}

sub type {
	return 'ETU';
}

PARAM! nom;
PARAM! prenom;

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
DEBUG! "$univ $annee $etape $typeFile";
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
	my $self = new ($class,  $univ, $eppn, $nom, $prenom, $eppn, $courriel);

	if ($self) {
		Dao->dao->addPerson(type(), $eppn, $nom, $prenom, $courriel, "");
		my $nbEtap;
		foreach my $code ($self->setCodesEtape($univ, @_)) {
			Dao->dao->addPersonneEtap($eppn, $code, type(), ++$nbEtap);
		}
		return $self;
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
	my $self = new Personne($eppn, $nom, $prenom, $eppn, $courriel);
	if ($self) {
		$self->{univ} = $univ;
		return bless $self, $class;
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
	my $self = new Personne($eppn, $nom, $prenom, $courriel);

	if ($self) {
		return bless $self, $class;
	}
}
sub type {
	return 'SUPERVISEUR';
}

1;
