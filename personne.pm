use strict;
use utf8;

#########
#
#
package Personne;

sub new {
	my $class = shift;
	my @info = @_;
	my $self = {
		info => \@info
	};
	return bless $self, $class;
}

sub setCodesEtape {
	my $self = shift; 
	my @codesEtape;
	if (@_ > 1 ) {
		foreach my $code (@_) {
			push ( @codesEtape, $code);
		}
	} else {
		@codesEtape = split ('@', $_[0]);
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
	my $diplome = shift;
	my $cohorte =shift;
	return (
		["model_code","dossierModeles","cohorte"],
		["kapc/etudiants/modeles.batch-creer-etudiants","${diplome}${univ}kapc/etudiants/modeles","${diplome}${univ}kapc/etudiants/instances/${cohorte}_${annee}"],
		["eppn","nomFamilleEtudiant","prenomEtudiant","courrielEtudiant","matriculeEtudiant"]
	)
}

sub new {
	my $class = shift;
		# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
	my $matricule = shift;
		# liste des infos en sortie dans csv 
	my $self = new Personne($eppn, $nom, $prenom, $courriel, $matricule );
	$self->setCodesEtape(@_);
	return bless $self, $class;
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
	my $annee = shift;
	my $diplome = shift;
	my $cohorte =shift;
	return (
		["model_code","dossierModeles","instancesEnseignants","cohorte"],
		["kapc/enseignants/modeles.batch-creer-enseignants","${diplome}${univ}kapc/enseignants/modeles","${diplome}${univ}kapc/enseignants/instances/${cohorte}","${diplome}${univ}kapc-enseignants-${cohorte}"],
		["eppn","nomFamilleEnseignant","prenomEnseignant","courrielEnseignant"]
	)
}
sub new {
	my $class = shift;
			# liste des données en entrée du csv
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $courriel = shift;
		# liste des infos en sortie dans csv 
	my $self = new Personne( $eppn, $nom, $prenom, $courriel);
	$self->setCodesEtape(@_);
	return bless $self, $class;
}

sub type {
	return 'STAFF';
}

1;
