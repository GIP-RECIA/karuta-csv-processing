#!/usr/bin/perl

=encoding utf8

=head1 NAME

	cleanDB.pl

	Nettoyage de la base de donné sqlite karuta.db.

=head1 SYNOPSIS

	cleanDB.pl  [-f karuta.db.file] [-u univId] [-v versionNumber] 

=cut

use strict;
use utf8;
use Getopt::Long;
use open qw( :encoding(utf8) :std );
use FindBin;                    
use lib $FindBin::Bin;
use Pod::Usage qw(pod2usage);
use MyLogger ;#'DEBUG';

use Univ;

use Dao;
use Data::Dumper;
MyLogger::level(5,2);
my $dbFile = "karuta.db";
my $univId;
my $version;

unless (@ARGV && GetOptions ( "f=s" => \$dbFile, "u=s" => \$univId, "v=s" => \$version)) {
	my $myself = $FindBin::Bin . "/" . $FindBin::Script ;
	#$ENV{'MANPAGER'}='cat';
	pod2usage( -message =>"ERROR:	manque d'arguments", -verbose => 1, -exitval => 1 , -input => $myself, -noperldoc => 1 );
}

my $dao = new Dao($dbFile);

if ($univId) {
	if ($version) {
		print "On supprime les données de $univId du $version (O/N): ";
		my $choix = <STDIN>;
		chomp $choix;
		if ($choix eq 'O') {
			$dao->deleteAllVersion($univId, $version);
		}

	}
}
unless ($version) {
	print "liste des versions par établissement\n";
	foreach my $tuple (@{$dao->getVersionUniv($univId)} ){
		print "\t",$$tuple[0], "\t", $$tuple[1], "\n";
	}
	
}






#print Dumper($dao->getVersionUniv($univId));
