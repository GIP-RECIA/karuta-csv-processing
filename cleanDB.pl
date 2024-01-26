#!/usr/bin/perl

=encoding utf8

=head1 NAME

	cleanDB.pl

	Nettoyage de la base de donné sqlite karuta.db.

=head1 SYNOPSIS

	cleanDB.pl  karuta.db.file [univId] [versionNumber] 

=head1 DESCRIPTION

	Supprime, aprés confirmation, les données de karuta.db.file corespondantes à l'univId et versionNumber.
	Si pas de versionNumber supprime, après confirmation, toutes les données de l'univId.
	Si pas de confirmation affiche les versionNumbers existant pour l'unviId.
	Si pas d'univId affiche toutes les versionNumbers de tous les univId de la base.

=cut

use strict;
use utf8;
#use Getopt::Long;
use open qw( :encoding(utf8) :std );
use FindBin;                    
use lib $FindBin::Bin;
use Pod::Usage qw(pod2usage);
use MyLogger ;#'DEBUG';
use Dao;

unless (@ARGV) {
	my $myself = $FindBin::Bin . "/" . $FindBin::Script ;
	#$ENV{'MANPAGER'}='cat';
	pod2usage( -message =>"ERROR:	manque d'arguments", -verbose => 2, -exitval => 1 , -input => $myself, -noperldoc => 1 );
}

MyLogger->level(3,1);

my $dbFile = shift;
my $univId = shift;
my $version = shift;

my $dao = new Dao($dbFile);

if ($univId) {
	if ($version) {
		print "On supprime les données de $univId du $version (O/N): ";
		my $choix = <STDIN>;
		chomp $choix;
		if ($choix eq 'O') {
			$dao->deleteAllVersion($univId, $version);
			
		}
	} else {
		print "On supprime toutes les données de $univId  (O/N): ";
		my $choix = <STDIN>;
		chomp $choix;
		if ($choix eq 'O') {
			$dao->deleteAllUniv($univId);
		}
		exit;
	}
}
unless ($version) {
	print "liste des versions par établissement\n";
	foreach my $tuple (@{$dao->getVersionUniv($univId)} ){
		print "\t",$$tuple[0], "\t", $$tuple[1], "\n";
	}
}
