use strict;
use utf8;
use MyLogger;

#########
#
#
package Personne;

sub new {
	my $class = shift;
	my @info = @_;
	if (testInfo(@info)) {
		# eppn == login
		my $eppn = shift @info;
		push @info, $eppn;
		my $self = {
			info => \@info,
			files => {}
		};
		return bless $self, $class;
	}
	return 0;
}


sub inFile {
	my $self = shift;
	my $file = shift;
	my $files = $self->{files};
	return $$files{$file}++ ;
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
#	DEBUG! "set codes etapes : ", @_;
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
#	DEBUG! "return ", @codesEtape;
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
	return (
		["model_code","formation_code", "formation_label", "cohorte"],
		[	"kapc/8etudiants.batch-creer-etudiants-authentification-externe",
			"${univ}_${site}_${formation_code}",
			"${univ}_${site} - ${formation_label}",
			"${univ}_${typeFile}"
		],
		["nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","matriculeEtudiant", "loginEtudiant"]
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
		# liste des infos en sortie dans csv 
	my $self = new Personne($eppn, $nom, $prenom, $courriel, $matricule);
	if ($self) {
		$self->{univ} = $univ;
		$self->setCodesEtape($univ, @_);
		return bless $self, $class;
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
	my $annee = shift;  # attention $annee et $typeFile ne sont pas utilisé mais sont transmise
	my $etape = shift;
	my $typeFile = shift;
	my $site = $etape->site;
	my $formation = $etape->formation;
	my $formation_code = $formation->code;
	my $formation_label = $formation->label;
	my $cohorte = $etape->cohorte;
	return (
		["model_code","formation_code","formation_label"],
		[	"kapc/3enseignants.batch-creer-enseignants-authentification-externe",
			"${univ}_${site}_${formation_code}",
			"${univ}_${site} - ${formation_label}",
		],
		["nomFamilleEnseignant","prenomEnseignant","courrielEnseignant", "loginEnseignant"]
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
		# liste des infos en sortie dans csv 
	my $self = new Personne( $eppn, $nom, $prenom, $courriel);
	if ($self) {
		$self->{univ} = $univ;
		$self->setCodesEtape($univ, @_);
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
	my $self = new Personne( $eppn, $nom, $prenom, $courriel);

	if ($self) {
		return bless $self, $class;
	}
}
sub type {
	return 'SUPERVISEUR';
}

1;
