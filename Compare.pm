use strict;
use utf8;
use MyLogger;
use Dao;
use TraitementCsv;
use open qw( :encoding(utf8) :std );

package Compare;
use Data::Dumper;

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
sub compareEtapEtu1 {
	my ($id, $olds, $news, $iO, $iN) = @_;

	if ($iN < @$news ) {
		#il reste des nouvelles étapes
		my $newE = $$news[$iN];
		if ($iO < @$olds ) {
			#il reste des anciennes etapes
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

sub compareEtapEtu {
	my ($id, $olds, $news) = @_;
	my $principaleNew = $self->dao->getEtapeEtu($id);
	my $principaleOld = $self->dao->getEtapeEtu($id, 1, $self->date2);


	#la  nouvelles étape principale
	my $newE = $$news[0];
	my $oldE = $$olds[0];
	if ($newE) {
				
		if ($oldE) {
			$$olds[0] = '';
		} else {
			$oldE = $principaleOld->etap;
		}
		$$news[0] = '';
		modifEtap($id, $oldE, $newE);
	} elsif ($oldE) {
		$newE = $principaleNew->{etap};
		modifEtap($id, $oldE, $newE);
	} else {
		#cas ou l'on permute l'etape principale avec une déjà existante
		if ( $principaleNew->diffEtapFormation($oldE)) {
			modifEtap($id, $principaleOld, $principaleNew );
		}
	}
	delEtaps($id, $principaleOld, @$olds);
	addEtaps($id, $principaleNew, @$news);
}

sub modifEtap {
	my ($id, $old, $new) = @_;
	unless ($old->isa('Etape')) {
		$old = $self->dao->getEtape($old, $self->date1);
	}
	unless ($new->isa('Etape')) {
	   $new = $self->dao->getEtape($new);
	}
	TraitementCsv::printModifEtapETU($id, $old, $new);
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
			TraitementCsv::printDelEtapETU($id, $etap1, $self->dao->getEtape($etapCod, $self->date1));
		}
	}
}

sub delEtu {
	my $id = shift;
	my $etap1 = shift;
	TraitementCsv::printDelETU($id, $etap1);
}



sub compareCohorte {
	$self = shift;
	TraitementCsv::init('ETU', $self->univ, $self->date2, $self->annee, $self->tmp);

	my ($new, $old) = $self->dao->diffPersonneEtap('ETU');

	while (my ($idPersonne, $newEtapes ) = each %$new ) {
		my $oldEtapes = $$old{$idPersonne};

		if ($oldEtapes && @$oldEtapes) {
			compareEtapEtu($idPersonne, $oldEtapes, $newEtapes);
			delete $$old{$idPersonne};
		} else {
			addEtu($idPersonne, @$newEtapes);
		}
	}
	while (my ($idPersonne, $oldEtapes ) = each %$old ) {
		my $etap1 = $self->dao->getEtapeEtu($idPersonne, 1, $self->date1);
		delEtaps($idPersonne, $etap1, @$oldEtapes);
		delEtu($idPersonne, $etap1);
	}
}

sub initCohorte {
	$self = shift;
	TraitementCsv::init('ETU', $self->univ, $self->date2, $self->annee, $self->tmp);
	my $new = $self->dao->allPersonneEtap('ETU');
	while (my ($idPersonne, $newEtapes ) = each %$new ) {
	#	FATAL! Dumper($newEtapes)  if ($idPersonne eq '22204658t@univ-tours.fr') ;
		addEtu($idPersonne, @$newEtapes);
	}
}

sub compareStaff {
	$self = shift;
	TraitementCsv::init('STAFF', $self->univ, $self->date2, $self->annee, $self->tmp);
	my ($new, $old) = $self->dao->diffPersonneEtap('STAFF');

	while (my ($idPersonne, $oldEtapes ) = each %$old) {
		foreach my $etapCod (@$oldEtapes) {
			if ($etapCod) {
				TraitementCsv::printDelEtapSTAFF($idPersonne, $self->dao->getEtape($etapCod, $self->date1));
			}
		}
		unless (exists $$new{$idPersonne}) {
			TraitementCsv::printDelSTAFF($idPersonne)
		}
	}
}



#22200947t@univ-tours.fr T01TB2MRC => T01TB2MMV
#21703031t@univ-tours.fr B30BB3DES ajouté
1;
