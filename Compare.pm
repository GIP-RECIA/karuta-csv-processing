use strict;
use utf8;
use MyLogger;
use Dao;
use TraitementCsv;

package Compare;

sub new {
	my ($class, $univ, $dao, $annee, $tmpRep, $oldDate, $newDate) = @_;

	if ($newDate) {
		$dao->version($newDate);
	} else {
		$newDate = $dao->version;
	}

	if ($oldDate) {
		$dao->lastVersion($oldDate);
	} else {
		$oldDate = $dao->lastVersion;
	}
	

	
	
	my $self = {
		DAO => $dao,
		UNIV => $univ,
		DATE1 => $oldDate,
		DATE2 => $newDate,
		ANNEE => $annee,
		TMP => $tmpRep
	};
	return bless $self, $class;
}


# on cherche les ETU qui ont changés de cohorte (étap)

PARAM! dao;
PARAM! univ;
PARAM! date1;
PARAM! date2;
PARAM! annee;
PARAM! tmp;

my $self;

# on cherche les ETU qui ont changé de cohorte (étap)
sub compareEtapEtu {
	my ($id, $olds, $news, $iO, $iN) = @_;

	if ($iN < @$news ) {
		#il reste des nouvelles étapes
		my $newE = $$news[$iN];
		if ($iO < @$olds ) {
			#il reste des anciennes etapes
			DEBUG! "$id $iN $iO";
			my $oldE = $$olds[$iO];
			if ($newE) {
				if ($oldE) {
					modifEtap($id, $oldE, $newE);
				} else {
					return compareEtapEtu($id, $olds, $news, $iO+1,  $iN);
				}
			} elsif ($oldE) {
				return compareEtapEtu($id, $olds, $news, $iO, $iN+1);
			} 
			return compareEtapEtu($id, $olds, $news, $iO+1, $iN+1);
			
		}
		# il n'y plus d'ancienne etape
		my $etap1 = $self->dao->getEtapeEtu($id);
		
		addEtaps($id, $etap1, @$news[$iN .. $#$news]);
	} elsif ($iO < $olds ) {
		# il n'y plus que des aciennes étapes
		my $etap1 = $self->dao->getEtapeEtu($id);
		delEtaps($id, $etap1, @$olds[$iO .. $#$olds]);
	}
}

sub modifEtap {
	my ($id, $old, $new) = @_;
	TraitementCsv::printModifEtapETU($id, $self->dao->getEtape($old), $self->dao->getEtape($new));
}

sub addEtaps {
	my $id = shift;
	my $etap1 = shift;
	foreach my $etapCod (@_) {
		if ($etapCod) {
			TraitementCsv::printAddEtapETU($id, $etap1, $self->dao->getEtape($etapCod));
		}
	}
}


sub addEtu {
	my $id = shift;
	my $etapeCod = shift;
	DEBUG! "add personne $id etap = $etapeCod";
	my $personne = $self->dao->getPersonne($id, 'ETU');

	my $etape = $self->dao->getEtape($etapeCod);
	TraitementCsv::printInformationFileETU($etape, $personne);
	if (@_) {
		addEtaps($id, $etape, @_);
	}
}

sub delEtaps {
	my $id = shift;
	my $etap1 = shift;
	foreach my $etapCod (@_) {
		if ($etapCod) {
			DEBUG! "$id del $etapCod";
			TraitementCsv::printDelEtapETU($id, $etap1, $self->dao->getEtape($etapCod));
		}
	}
}




sub compareCohorte {
	$self = shift;
	DEBUG! "compareCohorte";
	TraitementCsv::init('ETU', $self->univ, $self->date2, $self->annee, $self->tmp);
	
	my ($new, $old) = $self->dao->diffPersonneEtap('ETU');
	
	while (my ($idPersonne, $newEtapes ) = each %$new ) {
		my $oldEtapes = $$old{$idPersonne};
		if ($oldEtapes && @$oldEtapes) {
			compareEtapEtu($idPersonne, $oldEtapes, $newEtapes, 0, 0);
			delete $$old{$idPersonne};
		} else {
			addEtu($idPersonne, @$newEtapes);
		}
	}
	while (my ($idPersonne, $oldEtapes ) = each %$old ) {
		my $etap1 = $self->dao->getEtapeEtu($idPersonne, 1, $self->date1);
		delEtaps($idPersonne, $etap1, @$oldEtapes)
	}
}



1;
