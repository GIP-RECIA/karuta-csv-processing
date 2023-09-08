use strict;
use utf8;
use MyLogger;

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
		@codesEtape = map ({s/\s*(\S+)\s*/\1/; $_} @_);
		if ($filtre) {
			DEBUG! " : ", @codesEtape;
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


sub entete {
	my $class = shift;
	my $univ = shift;
	my $annee = shift;
	my $etape = shift;
	my $typeFile = shift;
	my $site = $etape->site;
	my $formation = $etape->formation;
	my $formation_label = $formation->label;
	my $formation_code = $formation->code;
	my $cohorte = $etape->cohorte;

DEBUG! "entete ETU formation_label: $formation_label; $typeFile; $cohorte";
	return (
		["model_code","formation_code", "formation_label", "cohorte", "debutFormation","","","",""],
		[	"ih2ef/1stagiaires.batch-creer-etudiants",
			$etape->codeSise, # $formation_code
			"${formation_label}",
			"$cohorte", # "${typeFile}"
			"01/09/$annee",
			"","","",""
		],
		["eppn","nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","civiliteEtudiant","loginEtudiant","academieEtudiant","fonctionEtudiant","naissanceEtudiant"]
	)
}

sub new {
	my $class = shift;
	my $univ = shift;
		# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $matricule = shift;
	my $codesEtape= shift;
	my $civile = shift;
	my $naissance = shift;
	my $academie = shift;
	my $fonction = shift;
		# identifiant + liste des infos en sortie dans csv
	my $self = new Personne($eppn, $eppn, $nom, $prenom, $courriel, $civile, $courriel, $academie, $fonction, $naissance);
	if ($self) {
		$self->{univ} = $univ;
		$self->setCodesEtape($univ, $codesEtape);
		$self->{mail} = $courriel;
		return bless $self, $class;
	} else {
		WARN! "new etudiant ($eppn, $nom, $prenom, $courriel,  $eppn)";
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

sub new {
	my $class = shift;
	my $univ = shift;
			# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
		# identifiant + liste des infos en sortie dans csv
	my $self = new Personne($eppn, $nom, $prenom, $eppn, $courriel);
	if ($self) {
		$self->{univ} = $univ;
		$self->setCodesEtape($univ, @_);
		return bless $self, $class;
	} else {
		WARN! "new staff ($eppn, $nom, $prenom,   $eppn, $courriel)";
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
	my $self = new Personne( $eppn, $nom, $prenom, $courriel);

	if ($self) {
		return bless $self, $class;
	}
}
sub type {
	return 'SUPERVISEUR';
}

1;
