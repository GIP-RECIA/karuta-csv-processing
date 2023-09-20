use strict;
use utf8;
use DBI;

use MyLogger;

package Dao;

sub new {
	my $class = shift;
	my $dbFile = shift;
	my $univ = shift;
	my $jour = shift;

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

		$statement =
			q/create table if not exists personnes (
					univ char(10) ,
					version char(10),
					id varchar(256),
					nom varchar(256),
					prenom varchar(256),
					mail varchar(256),
					matricule varchar(256),
					status char(5),
					primary key (univ , version, id),
					foreign key (univ, version) references univs,
					unique (univ, version, status, id)
					
				)
			/;
		$dbh->do($statement) or die $dbh->errstr;

		$statement =
			q/create table if not exists formations (
					univ char(10),
					version char(10),
					codeFormation varchar(256),
					site varchar(256),
					label varchar(256),
					primary key (univ , version, codeFormation),
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
					primary key (univ , version, codeEtape),
					foreign key (univ, version, codeFormation) references formations
				)
			/;
		$dbh->do($statement) or die $dbh->errstr;

		$statement = q/insert into univs values ( ?, ?)/;
		my $sth = $dbh->prepare($statement);
		$sth ->execute($univ, $jour) or FATAL! $dbh->errstr;
		my $self = {
			db => $dbh,
			file => $dbFile,
			jour => $jour,
			univ => $univ
		};
		return bless $self, $class;
	}
	ERROR! "connetion failed : $dbFile;";
	return 0;
}
sub univ {
	my $self = shift;
	return $self->{'univ'},
}
sub version {
	my $self = shift;
	return $self->{'jour'},
}

sub addPerson {
	my $self = shift;
	my $status = shift;
	my $eppn = shift;
	my $nom = shift;
	my $prenom = shift;
	my $mail = shift;
	my $matricule = shift;

	WARN! $self->univ,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status";
	my $dbh = $self->{'db'};
	my $statement = q/select * from personnes where univ = ? and version = ? and id = ? and status = ?/;
	my $sth = $dbh->prepare($statement);
	$sth->execute($self->univ, $self->version, $eppn, $status) or FATAL! $dbh->errstr;
	my @t = $sth->fetchrow_array();
	
	unless (@t) {
		$statement = q/insert into personnes values (?, ?, ?, ?, ?, ?, ?, ?)/;
		$sth = $dbh->prepare($statement);
		$sth ->execute($self->univ, $self->version, $eppn, $nom , $prenom, $mail, $matricule, $status) or FATAL! $dbh->errstr;
	} else {
		
		if ($nom ne $t[3] or  $prenom ne $t[4], $mail ne $t[5], $matricule ne $t[6]) {
			ERROR! "(", $self->univ,", ", $self->version,", $eppn, $nom , $prenom, $mail, $matricule, $status) != (", join(", " ,@t), ")" ;  
		}
	}
};



1;
