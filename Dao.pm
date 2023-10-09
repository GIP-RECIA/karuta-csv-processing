use strict;
use utf8;
use DBI;

use MyLogger;
use personne;

package Dao;



#use vars      @EXPORT;
my $dao_default;

sub dao {
	if ($dao_default) {
		return $dao_default;
	}
	ERROR! "Dao non instancié";
	return 0;
}

sub new {
	my $class = shift;
	my $dbFile = shift;
	my $univ = shift;
	my $jour = shift;

	if ($univ->isa('Univ')) {
		if ($jour) {
			$univ->dateFile($jour);
		} else {
			$jour = $univ->dateFile;
		}
		$univ = $univ->id;
	}

	FATAL! "Dao sans jour définit" unless $jour;
	
	if ($dao_default) {
		$dao_default->db->close;
		$dao_default = 0;
	}
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dbFile","","");
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
					foreign key (univ, version, idPersonne, status) references personnes,
					foreign key (univ, version, codeEtape) references etapes
			)/;
		$dbh->do($statement) or die $dbh->errstr;
		
# les tables des cohortes injectés dans karuta pas sur quelle soit isomorphe à etap
#		$statement = 
#			q/create table if not exists cohorte (
#				univ char(10),
#				version char(10),
#				fileName varchar(256),
#				formationCode varchar(256),
#				cohorteCode varchar(256),
#				primary key (univ, version,  cohorteCode) on conflict ignore,
#				foreign key (univ, version, formationCode) references formations
#			)/;
#		$dbh->do($statement) or die $dbh->errstr;

		$statement = q/insert into univs values ( ?, ?)/;
		my $sth = $dbh->prepare($statement);
		$sth ->execute($univ, $jour) or FATAL! $dbh->errstr;
		my $self = {
			DB => $dbh,
			file => $dbFile,
			VERSION => $jour,
			UNIV => $univ
		};
		$dao_default = bless $self, $class;
		return $dao_default;
	}
	ERROR! "connetion failed : $dbFile;";
	return 0;
}
PARAM! univ;
PARAM! version;
PARAM! db;

# fixe la version précedante pour les diffs , vérifie qu'elle existe.
sub lastVersion {
	my $self = shift;
	my $oldV = shift;
	unless ($oldV) {
		return  $self->{LASTVERSION};
	}
	my $dbh = $self->db;
	my $statement = q/select * from univs where univ = ? and version = ?/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ, $oldV) or FATAL! $dbh->errstr;
	if ($sth->fetchrow_array()) {
		$self->{LASTVERSION} = $oldV;
	} else {
		$oldV = 0;
	}
}


sub addPerson {
	my $self = shift;
	my $status = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $mail = shift;
	my $matricule = shift;

	DEBUG! "addPersonn ",  $self->univ,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status";
	my $dbh = $self->db;
	my $statement = q/select * from personnes where univ = ? and version = ? and idPersonne = ? and status = ?/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ, $self->version, $eppn, $status) or FATAL! $dbh->errstr;
	my @t = $sth->fetchrow_array();
	
	unless (@t) {
		$statement = q/insert into personnes values (?, ?, ?, ?, ?, ?, ?, ?)/;
		$sth = $dbh->prepare($statement);
		$sth ->execute($self->univ, $self->version, $eppn, $nom , $prenom, $mail, $matricule, $status) or FATAL! $dbh->errstr;
	} else {
		
		if ($nom ne $t[3] ||  $prenom ne $t[4] || $mail ne $t[5] || $matricule ne $t[6]) {
			ERROR! "(", $self->univ,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status) != (", join(", " ,@t), ")" ;  
		}
	}
};

	
sub getPersonne {
	my $self = shift;
	my $idPersonne = shift;
	my $status = shift;
	my $dbh = $self->db;

	my $statement = q/select univ, idPersonne, nom, prenom, mail, matricule from personnes
					where univ = ? and version = ? and idPersonne = ? and status = ?/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ, $self->version, $idPersonne, $status) or ERROR! $dbh->errstr ," : ", $dbh->err;

	my $personne;
	my @tuple = $sth->fetchrow_array;
	if ($status == 'ETU') {
		$personne = new Etudiant(@tuple);
	} elsif ($status == 'STAFF' ) {
		$personne = new Staff(@tuple);
	}
	return $personne;
}


sub addFormation {
	my $self = shift;
	my ($code , $site, $label) = @_;

	DEBUG! "addFormation : ", $self->univ,", ", $self->version,", $code , $site, $label";
	my $dbh = $self->db;
	
	my $statement = q/insert into formations values (?, ?, ?, ?, ?, null, null)/;
	my $sth = $dbh->prepare($statement);
	unless ($sth ->execute($self->univ, $self->version, $code, $site, $label) ) {
		if ($dbh->err == 19) {
			$statement = q/select label from formations where univ = ? and version = ? and code = ? and site = ?/;
			$sth = $dbh->prepare($statement);
			$sth->execute($self->univ, $self->version, $code, $site) or FATAL! $dbh->errstr," : ", $dbh->err;
			my @t = $sth->fetchrow_array();
			if ($t[0] ne $label) {
				ERROR! "formation : $code; avec différent labels :", $label, ":", $t[0] ,":"; 
			}
		} else {
			ERROR! $dbh->errstr ," : ", $dbh->err;
		}
	};
}

sub updateFormation {
	my $self = shift;
	my ($code , $site, $formationCode, $formationLabel) = @_;
	my $dbh = $self->db;
	my $statement = q/update formations set formationCode = ?, formationLabel = ? where univ = ? and version = ? and code = ? and site = ?/;

	my $sth = $dbh->prepare($statement);
	$sth ->execute($formationCode, $formationLabel, $self->univ, $self->version, $code, $site) or  FATAL! $dbh->errstr;
}


sub addEtape {
	my $self = shift;
	my ($codeEtape, $libEtape, $codeFormation, $site, $cohorte) = @_;
	DEBUG! "addEtap : ", $self->univ,", ", $self->version,",codeEtape, libEtape, codeFormation";

	my $dbh = $self->db;
	
	my $statement = q/insert into etapes values (?, ?, ?, ?, ?, ?, ?, null)/;
	my $sth = $dbh->prepare($statement);
	unless ($sth ->execute($self->univ, $self->version, $codeEtape, $libEtape, $codeFormation, $site, $cohorte) ) {
		if ($dbh->err == 19) {
			$statement = q/select libEtape from etapes where univ = ? and version = ? and  codeEtape = ? /;
			$sth = $dbh->prepare($statement);
			$sth->execute($self->univ, $self->version, $codeEtape ) or FATAL! $dbh->errstr," : ", $dbh->err;
			my @t = $sth->fetchrow_array();
			if ($t[0] ne $libEtape) {
				ERROR! "etape : $codeEtape; non unique; libélés :", $libEtape, ":", $t[0] ,":"; 
			}
		} else {
			ERROR! $dbh->errstr ," : ", $dbh->err;
		}
	};
}


sub updateCohorte {
	my $self = shift;
	my $etapCode = shift;
	my $fileName = shift;
	if ($fileName) {
		my $dbh = $self->db;
		my $statement = q/update etapes set cohorteFile = ? where univ = ? and version = ? and codeEtape = ?/;
		my $sth = $dbh->prepare($statement);
		$sth ->execute($fileName, $self->univ, $self->version, $etapCode) or  FATAL! $dbh->errstr;
	}
}

sub addPersonneEtap {
	my $self = shift;
	my ($idPersonne, $codeEtape, $status, $ordre) = @_;
	my $dbh = $self->db;
	
	my $statement = q/insert into personneEtape values (?, ?, ?, ?, ?, ?)/;
	my $sth = $dbh->prepare($statement);
	$sth ->execute($self->univ, $self->version, $idPersonne, $codeEtape, $status, $ordre) or ERROR! $dbh->errstr ," : ", $dbh->err;
}


######## pour les comparaisons:

sub execDiffPersonEtap {
	my $dbh = shift;
	my $sth = shift;
	$sth->execute(@_) or ERROR! $dbh->errstr ," : ", $dbh->err;
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

	my $statement =
		q/select idPersonne, codeEtape, ordre from personneEtape pe1 where univ = ?1 and version = ?3 and status = ?2
		and not exists (select idPersonne, codeEtape from personneEtape pe2 where univ = ?1 and version = ?4 and status = ?2 and idPersonne = pe1.idPersonne and codeEtape = pe1.codeEtape) /;

	my $sth = $dbh->prepare($statement);
	DEBUG! $statement;
	return (
		execDiffPersonEtap($dbh, $sth, $self->univ, $status, $self->version, $self->lastVersion),
		execDiffPersonEtap($dbh, $sth, $self->univ, $status, $self->lastVersion, $self->version)
		);
}


1;
