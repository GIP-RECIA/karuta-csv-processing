use strict;
use utf8;
use DBI;

use Personne;
use Formation;
use MyLogger ;#'DEBUG';
#use Filter::sh "tee " . __FILE__ . ".pl";

package Dao;
use Data::Dumper;

#use open qw( :encoding(utf8) :std );

#use vars      @EXPORT;
my $dao_default;

PARAM! univ;
PARAM! version;
PARAM! db;
PARAM! dbFile;
PARAM! file;
PARAM! LASTVERSION;
PARAM! sth;

sub dao {
	if ($dao_default) {
		return $dao_default;
	}
	ERROR! "Dao non instancié";
	return 0;
}

sub new {
	my $self = NEW!;
	my $dbFile = shift;

	my $dbh;
	$dbh = DBI->connect("dbi:SQLite:dbname=$dbFile","","", {PrintError => 0, sqlite_unicode => 1 }) or FATAL!  $dbh->errstr;
	$dbh->do("PRAGMA foreign_keys = ON");

	db! = $dbh;
	file! = $dbFile;
	return $dao_default = $self;
}

sub create {
	my $class = shift;
	my $dbFile = shift;
	my $univ = shift;
	my $jour = shift;

	my $univId;
	if ($univ->isa('Univ')) {
		if ($jour) {
			$univ->dateFile($jour);
		} else {
			$jour = $univ->dateFile;
		}
		$univId = $univ->id;
	} else {
		FATAL! "$univ not Univ object";
	}

	FATAL! "Dao sans jour définit" unless $jour;
	
	if ($dao_default) {
		$dao_default->db->disconnect();
		$dao_default = 0;
	}
	my $self= $class->new($dbFile);
	my $dbh = db!;
	if ($dbh) {

		my $statement =
			q/create table if not exists univs (
					univ char(10),
					version char(10),
					primary key (univ , version) on conflict ignore
				)
			/;
			
		$dbh->do($statement) or die $dbh->errstr;

# les tables des entrées

		$statement =
			q/create table if not exists personnes (
					univ char(10) ,
					version char(10),
					idPersonne varchar(256),
					nom varchar(256),
					prenom varchar(256),
					mail varchar(256),
					matricule varchar(256),
					status char(5),
					primary key (univ , version, idPersonne, status) ,
					foreign key (univ, version) references univs,
					unique (univ, version, status, idPersonne) on conflict fail
				)
			/;
		$dbh->do($statement) or die $dbh->errstr;

		$statement =
			q/create table if not exists formations (
					univ char(10),
					version char(10),
					code varchar(256),
					site varchar(256),
					label varchar(256),
					formationCode varchar(256), 
					formationLabel varchar(256),
					primary key (univ , version, code, site) on conflict fail,
					unique (univ , version, formationCode) on conflict fail,
					foreign key (univ, version) references univs
				)
			/;
		$dbh->do($statement) or die $dbh->errstr;
		$statement =
			
			q/create table if not exists etapes (
					univ char(10),
					version char(10),
					codeEtape  varchar(10),
					libEtape varchar(256),
					codeFormation varchar(256),
					site varchar(256),
					cohorteCode varchar(256),
					cohorteFile varchar(256),
					primary key (univ , version, codeEtape) on conflict fail,
					foreign key (univ, version, codeFormation, site) references formations
				)
			/;
		$dbh->do($statement) or die $dbh->errstr;

		$statement =
			q/create table if not exists personneEtape (
					univ char(10) ,
					version char(10),
					idPersonne varchar(256),
					codeEtape  varchar(10),
					status char(5),
					ordre integer(100),
					primary key (univ , version, status, codeEtape, idPersonne) on conflict ignore,
					unique (univ , version, status, idPersonne, ordre) on conflict fail, 
					foreign key (univ, version, idPersonne, status) references personnes,
					foreign key (univ, version, codeEtape) references etapes
			)/;
		$dbh->do($statement) or die $dbh->errstr;
		
# les tables des cohortes injectés dans karuta pas sur quelle soit isomorphe à etap
#		$statement = 
#			q/create table if not exists cohorte (
#				univ char(10),
#				version char(10),
#				id varchar(10),
#				fileName varchar(256),
#				formationCode varchar(256),
#				cohorteCode varchar(256),
#				primary key (univ, version, id) on conflict ignore,
#				unique (univ, version, cohorteCode),
#				foreign key (univ, version, formationCode) references formations
#			)/;
#		$dbh->do($statement) or die $dbh->errstr;

		$statement = q/insert into univs values ( ?, ?)/;
		my $sth = $dbh->prepare($statement);
		$sth ->execute($univId, $jour) or FATAL! $dbh->errstr;
		version! = $jour;
		univ! = $univ;

		$dao_default = $self;
		return $dao_default;
	}
	ERROR! "connetion failed : $dbFile;";
	return 0;
}


# fixe la version précedante pour les diffs , vérifie qu'elle existe.
# si n'est pas fixé recupère la dernière.
sub lastVersion {
	my $self = shift;
	my $oldV = shift;
	unless ($oldV) {
		$oldV = $self->LASTVERSION;
		unless ($oldV) {
			my $dbh = $self->db;
			my $statement = q/select max(version) from univs where univ = ? and version < ?/;
			my $sth = $dbh->prepare($statement);
			$sth ->execute($self->univ->id, $self->version) or FATAL! $dbh->errstr;
			if (($oldV) = $sth->fetchrow_array()) {
				return $self->LASTVERSION($oldV);
			} 
			return $self->LASTVERSION('');
		}
		return $oldV;
	}
	my $dbh = $self->db;
	my $statement = q/select * from univs where univ = ? and version = ?/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ->id, $oldV) or FATAL! $dbh->errstr;
	if ($sth->fetchrow_array()) {
		return $self->LASTVERSION($oldV);
	} 
	return $self->LASTVERSION('');
}

=begin

sub addPerson {
	my $self = shift;
	my $status = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $mail = shift;
	my $matricule = shift;

	my $dbh = $self->db;
	my $statement = q/select * from personnes where univ = ? and version = ? and idPersonne = ? and status = ?/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ->id, $self->version, $eppn, $status) or FATAL! $dbh->errstr;
	my @t = $sth->fetchrow_array();

	unless (@t) {
		$statement = q/insert into personnes values (?, ?, ?, ?, ?, ?, ?, ?)/;
		$sth = $dbh->prepare($statement);
		$sth ->execute($self->univ->id, $self->version, $eppn, $nom , $prenom, $mail, $matricule, $status) or FATAL! $dbh->errstr;
	} else {
		if ($nom ne $t[3] ||  $prenom ne $t[4] || $mail ne $t[5] || $matricule ne $t[6]) {
			ERROR! "(", $self->univ->id,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status) != (", join(", " ,@t), ")" ;
		}
		return 1;
	}
	return 1;
};

=cut

sub addPerson {
	my $self = shift;
	my $status = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $mail = shift;
	my $matricule = shift;
	my $dbh = $self->db;
	my $statement = q/insert into personnes values (?, ?, ?, ?, ?, ?, ?, ?)/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ->id, $self->version, $eppn, $nom , $prenom, $mail, $matricule, $status);
	if ($sth->err) {
		if ($sth->err == 19) {
			$statement = q/select * from personnes where univ = ? and version = ? and idPersonne = ? and status = ?/;
			my $sth = $dbh->prepare($statement);
			$sth->execute($self->univ->id, $self->version, $eppn, $status) or FATAL! $dbh->errstr, " ", $dbh->err;
			my @t = $sth->fetchrow_array();
			if ($nom ne $t[3] ||  $prenom ne $t[4] || $mail ne $t[5] || $matricule ne $t[6]) {
				ERROR! "(", $self->univ->id,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status) != (", join(", " ,@t), ")" ;
			}
		} else {
			FATAL! $dbh->errstr, " ", $sth->err;
		}
		return 0;
	}
	return 1;
}

sub getPersonne {
	my $self = shift;
	my $idPersonne = shift;
	my $status = shift;

	my $dbh = $self->db;

	my $statement = q/select univ, idPersonne, nom, prenom, mail, matricule from personnes
					where univ = ? and version = ? and idPersonne = ? and status = ?/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ->id, $self->version, $idPersonne, $status) or ERROR! $dbh->errstr ," : ", $dbh->err;

	my $personne;
	my @tuple = $sth->fetchrow_array;
	if ($status eq 'ETU') {
		($personne = new Etudiant(@tuple)) or FATAL! "getPersonne ETU $idPersonne: $!";
#		if ($personne->id eq '22204658t@univ-tours.fr') {DEBUG! Dumper($personne), Dumper(@tuple);}
		
	} elsif ($status eq 'STAFF' ) {
		$personne = new Staff(@tuple);
	}
	return $personne;
}

sub addFormation {
	my $self = shift;
	my ($code , $site, $label) = @_;

	my $dbh = $self->db;
	
	my $statement = q/insert into formations values (?, ?, ?, ?, ?, null, null)/;
	my $sth = $dbh->prepare($statement) or FATAL! $dbh->errstr," : ", $dbh->err;

	$sth->execute($self->univ->id, $self->version, $code, $site, $label);
	if ($sth->err) {
		DEBUG! "sth->err = ", $sth->err;
		if ($sth->err == 19) {
			$statement = q/select label from formations where univ = ? and version = ? and code = ? and site = ?/;
			$sth = $dbh->prepare($statement);
			$sth->execute($self->univ->id, $self->version, $code, $site) or FATAL! $dbh->errstr," : ", $dbh->err;
			my @t = $sth->fetchrow_array();
			if ($t[0] ne $label) {
				ERROR! "formation : $code; avec différent labels :", $label, ":", $t[0] ,":";
			} 
		} else {
			ERROR! $sth->errstr ," : ", $sth->err;
		}
		return 0;
	}
	return 1;
}

sub updateFormation {
	my $self = shift;
	my ($code , $site, $formationCode, $formationLabel) = @_;
	my $dbh = $self->db;
	my $statement = q/update formations set formationCode = ?, formationLabel = ? where univ = ? and version = ? and code = ? and site = ?/;

	my $sth = $dbh->prepare($statement);
	$sth ->execute($formationCode, $formationLabel, $self->univ->id, $self->version, $code, $site) or  FATAL! $dbh->errstr;
}

sub getFormation {
	my $self = shift;
	my $codeFormation = shift;
	my $site = shift;
	my $version = shift;

	unless ($version) {
		$version = $self->version;
	}
	my $dbh = $self->db;

	my $statement = q/select label, site from formations where univ = ? and version = ? and code = ? and site = ?/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ->id, $version, $codeFormation, $site ) or FATAL! $dbh->errstr," : ", $dbh->err;
	my @t = $sth->fetchrow_array();

	return (Formation->new($self->univ->id, $codeFormation, @t))[0];
}


sub addEtape {
	my $self = shift;
	my ($codeEtape, $libEtape, $codeFormation, $site, $cohorte) = @_;

	my $dbh = $self->db;
	
	my $statement = q/insert into etapes values (?, ?, ?, ?, ?, ?, ?, null)/;
	my $sth = $dbh->prepare($statement);
	unless ($sth ->execute($self->univ->id, $self->version, $codeEtape, $libEtape, $codeFormation, $site, $cohorte) ) {
		if ($dbh->err == 19) {
			$statement = q/select libEtape from etapes where univ = ? and version = ? and  codeEtape = ? /;
			$sth = $dbh->prepare($statement);
			$sth->execute($self->univ->id, $self->version, $codeEtape ) or FATAL! $dbh->errstr," : ", $dbh->err;
			my @t = $sth->fetchrow_array();
			if ($t[0] ne $libEtape) {
				ERROR! "etape : $codeEtape; non unique; libélés :", $libEtape, ":", $t[0] ,":";
			}
		} else {
			ERROR! $dbh->errstr ," : ", $dbh->err;
		}
		return 0;
	};
	return 1;
}



sub createEtap {
	my $self = shift;
	my $version = shift;
	my ($site, $codeF) = @_[2,4];
	my $formation = Formation::byCle($site, $codeF);
	unless ($formation) {
		$formation = $self->getFormation($codeF, $site, $version);
	}
	return Etape->new($self->univ->id, @_, $formation->label, $formation);
}

sub getEtape {
	my $self = shift;
	my $codeEtap = shift;
	my $version = shift;
	my $dbh = $self->db;
	my $statement = q/select codeEtape, libEtape, site, cohorteCode, codeFormation from etapes where univ = ? and version = ? and codeEtape =?/;
	my $sth = $dbh->prepare($statement);

	unless ($version) {
		$version = $self->version;
	}
	$sth->execute($self->univ->id, $version, $codeEtap ) or FATAL! $dbh->errstr," : ", $dbh->err;
	my @t = $sth->fetchrow_array();
# $univ, $codeEtap, $libEtap, $site, $cohorte, $codeFormation, $labelFormation, $formation
	if (@t) {
		return $self->createEtap($version, @t);
	}
}

sub updateCohorte {
	my $self = shift;
	my $etapCode = shift;
	my $fileName = shift;
	if ($fileName) {
		my $dbh = $self->db;
		my $statement = q/update etapes set cohorteFile = ? where univ = ? and version = ? and codeEtape = ?/;
		my $sth = $dbh->prepare($statement);
		$sth ->execute($fileName, $self->univ->id, $self->version, $etapCode) or  FATAL! $dbh->errstr;
	}
}

sub addPersonneEtap {
	my $self = shift;
	my ($idPersonne, $codeEtape, $status, $ordre) = @_;
	my $dbh = $self->db;
	
	my $statement = q/insert into personneEtape values (?, ?, ?, ?, ?, ?)/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ->id, $self->version, $idPersonne, $codeEtape, $status, $ordre)
		or (DEBUG! " values \n", Dumper($self->univ->id, $self->version, $idPersonne, $codeEtape, $status, $ordre)
		and FATAL! $dbh->errstr ," : ", $dbh->err );
}


sub getEtapeEtu{
	my $self = shift;
	my ($idPersonne, $rang, $version) = @_;
	#recupere l'étape principale d'une personne rang et version sont facultatif;
	unless ($rang) {
		$rang = 1;
	}
	unless ($version) {
		$version = $self->version
	}
	my $dbh = $self->db;
	my $statement = q/select e.codeEtape, e.libEtape, e.site, e.cohorteCode, e.codeFormation
					from etapes e, personneEtape p
					where e.univ = ? and e.version = ? and e.codeEtape = p.codeEtape
					and p.univ = e.univ and p.version = e.version and p.idPersonne = ? and p.ordre = ? and p.status = 'ETU'
					/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ->id, $version, $idPersonne, $rang);

	my @t = $sth->fetchrow_array();
	if (@t) {
		return $self->createEtap($version, @t);
	}
	FATAL! "etape introuvable ($idPersonne, $rang, $version)";
}


######## pour les comparaisons:

sub execDiffPersonEtap {
	my $dbh = shift;
	my $sth = shift;
	$sth->execute(@_) or FATAL! $dbh->errstr ," : ", $dbh->err;
	my %res;
	while (my @tuple = $sth->fetchrow_array) {
		# push @{$res{$tuple[0]}}, ($tuple[1], $tuple[2]) ;
#		push @{$res{shift @tuple}}, {@tuple}; # un hash de tableau non ordoné
#		$res{$tuple[0]}->{$tuple[1]} = $tuple[2]; # hash de hash
		$res{$tuple[0]}[$tuple[2]-1] = $tuple[1]; # hash de tableau ordonné
	}
	return \%res;
}

sub diffPersonneEtap {
	my $self = shift;
	my $status = shift;
	my $dbh = $self->db;

	# la complication vient que pour un même codeEtape le codeFormation peut changer d'une version a l'autre
	my $statement =
		q/select pe1.idPersonne, pe1.codeEtape, pe1.ordre
		from personneEtape pe1, etapes e1
		where pe1.univ = ?1
		and pe1.version = ?3
		and pe1.status = ?2
		and e1.codeEtape = pe1.codeEtape
		and e1.univ = ?1
		and e1.version = ?3 
		and not exists
			(select pe2.idPersonne, pe2.codeEtape
			from personneEtape pe2, etapes e2
			where pe2.univ = ?1
			and pe2.version = ?4
			and pe2.status = ?2
			and pe2.idPersonne = pe1.idPersonne
			and pe2.codeEtape = pe1.codeEtape
			and e2.codeEtape = pe1.codeEtape
			and e2.codeFormation = e1.codeFormation
			and e2.univ = ?1
			and e2.version = ?4)
		order by pe1.idPersonne/;


	my $sth = $dbh->prepare($statement) or FATAL! "$statement\n",  $dbh->errstr ," : ", $dbh->err;
	#DEBUG! "univ=", $self->univ->id , ", status=$status, version=",$self->version,", lastversion=", $self->lastVersion;

	return (
			execDiffPersonEtap($dbh, $sth, $self->univ->id, $status, $self->version, $self->lastVersion),
			execDiffPersonEtap($dbh, $sth, $self->univ->id, $status, $self->lastVersion, $self->version)
		) ;
}

sub allPersonneEtap {
	my $self = shift;
	my $status = shift;
	my $dbh = $self->db;
	my $statement = q/select idPersonne, codeEtape, ordre from personneEtape pe1 where univ = ?1 and version = ?3 and status = ?2/;

	my $sth = $dbh->prepare($statement);
	return execDiffPersonEtap($dbh, $sth, $self->univ->id, $status, $self->version);
}

######### pour le netoyage de la base

sub getVersionUniv {
	my ($self, $univId) = @_;
	my $dbh = $self->db;

	my $query;
	if ($univId) {
		$query = q/select univ, version from univs where univ = ? order by version/;
	} else {
		$query = q/select univ, version from univs order by univ, version/;
	}
	my $sth = $dbh->prepare($query) or FATAL! "$query\n",  $dbh->errstr ," : ", $dbh->err;
	$univId ? $sth ->execute($univId) : $sth ->execute() or FATAL! "$query\n",  $dbh->errstr ," : ", $dbh->err;

	return ($sth->fetchall_arrayref);
}


sub execAllTableQuery {
	my $dbh = shift()->db;
	my $queryFormat = shift;

	my $rows = 0;
	$dbh->begin_work;

	for (qw/personneEtape etapes formations  personnes univs/) {
		my $query = sprintf($queryFormat, $_);
		$rows += ($dbh->do($query, undef, @_) or do {
			$dbh->rollback;
			FATAL! "$query ", @_ ,  $dbh->errstr ," : ", $dbh->err;
		});
	}
	$dbh->commit;
	INFO! "Nb lignes supprimées = $rows";
}

sub deleteAllUniv {
	my $self = shift;
	my $univId = shift;
	FATAL! ("deleteAllUniv manque l'univ " ) unless ($univId)  ;
	return $self->execAllTableQuery(q/delete from %s where univ = ?/, $univId);
}
sub deleteAllVersion {
	my $self = shift;
	FATAL! ("deleteAllVersion pas assez de parametre " ) if (@_ < 2)  ;
	return $self->execAllTableQuery(q/delete from %s where univ = ? and version = ?/, @_);
}

1;
