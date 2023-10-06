use strict;
use utf8;
use MyLogger;
use Dao;


package Compare;

sub new {
	my ($class, $dao, $oldDate, $newDate, $annee, $tmpRep) = @_;

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
		UNIV => $dao->univ,
		DATE1 => $oldDate,
		DATE2 => $newDate,
		ANNEE => $annee,
		TMP => $tmpRep
	};
	return bless $self, $class;
}


# on cherche les ETU qui ont changé de cohorte (étap)

PARAM! dao;
PARAM! univ;
PARAM! date1;
PARAM! data2;
PARAM! annee;
PARAM! tmp;



# on cherche les ETU qui ont changé de cohorte (étap)

sub compareEtapEtu {
	my ($id, $olds, $news, $iO, $iN) = @_;

	if ($iN < @$news ) {
		my $newE = $$news[$iN];
		if ($iO < @$olds ) {
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
		
		addEtaps($id, @$news[$iN .. $#$news]);
	} elsif ($iO < $olds ) {
		delEtaps($id, @$olds[$iO .. $#$olds]);
	}
}

sub modifEtap {
	my ($id, $old, $new) = @_;
	DEBUG! "$id  $old => $new";
}

sub addEtaps {
	my $id = shift;
	foreach my $etap (@_) {
		if ($etap) {
			DEBUG! "$id add $etap";
		}
	}
}

sub addEtu {
	my $id = shift;
	my $etape = shift;
	DEBUG! "add personne $id etap = $etape";
	getFileCohorte($etape);
	addEtaps($id, @_);
}

sub delEtaps {
	my $id = shift;
	foreach my $etap (@_) {
		if ($etap) {
			DEBUG! "$id del $etap";
		}
	}
}


my $self;
sub compareCohorte {
	$self = shift;
	Traitement::init('ETU', $self->univ, $self->date2, $self->annee, $self->tmp);
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
		delEtaps($idPersonne, @$oldEtapes)
	}
}

sub compareCohorteIt {
	my $self = shift;
	my ($new, $old) = $self->dao->diffPersonneEtap('ETU');

	while (my ($idPersonne, $newEtapes ) = each %$new ) {
		my $oldEtapes = $$old{$idPersonne};
		DEBUG! "$idPersonne";
		if ($oldEtapes && @$oldEtapes) {
			# cas il y a une liste ordonnée d'ancienne etapes la liste peut comprende des elements vide (correspondant sans doute a des etapes existante encore).
			my $idxNew = 0;
			my $idxOld = 0;
			while (($idxNew < @$newEtapes) && ($idxOld < @$oldEtapes)) {
				my $newE = $$newEtapes[$idxNew];
				my $oldE = $$oldEtapes[$idxOld];
				DEBUG! "$oldE ($idxOld) => $newE ($idxNew)";
				if ($newE) {
					if ($oldE) {
						#TODO newE remplace oldE
						DEBUG! "$idPersonne change $oldE par $newE";
 						$idxNew ++;
					} 
					$idxOld++;
				} else {
					$idxNew ++;
				}
			}
			while ($idxNew++ < @$newEtapes) {
				my $newE = $$newEtapes[$idxNew];
				if ($newE) {
					#TODO
					DEBUG! "$idPersonne add $newE";
				}
			}
			while ($idxOld++ < @$oldEtapes) {
				my $oldE = $$oldEtapes[$idxOld];
				if ($oldE) {
					#TODO oldE
					DEBUG! "$idPersonne supprime $oldE";
				}
			}
			#suppression du old car deja traité 
			delete $$old{$idPersonne};
		} else {
			my $idx;
			foreach my $newE (@$newEtapes) {
				$idx++;
				if ($newE) {
					if ($idx == 1) {
						DEBUG! "nouveau $idPersonne avec  $newE";
					} else {
						DEBUG! "$idPersonne ajout  $newE";
					}
				}
			}
		}
	}
	while (my ($idPersonne, $oldEtapes ) = each %$old ) {
		foreach my $oldE (@$oldEtapes) {
			DEBUG! "delete $idPersonne";
			my $idx++;
			if ($oldE) {
				DEBUG! " 	suppression $oldE"; 
			}
		}
	}
}

sub getFileCohorte {
	my $etap = shift;
	$self->dao->
}

1;
