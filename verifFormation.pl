#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

=pod
	Synopsie : verifFormation.pl fichierCodeEtape formation.csv
	
	script  pour orleans pour verifier le fichierCodeEtape des code etape que l'on garde pour être sure que l'on a une ligne dans formation.csv 

=cut
my $codeFile = shift;
my $formationFile = shift;

open COD, "$codeFile" or die "$codeFile $!";
open FORM, "$formationFile" or die "$formationFile $!";

my %allFormationInList;

while (<COD>) {
	chop ;
	next if /^\s*(#.*)?$/;
	$allFormationInList{$_}=0;
}

print "Codes manquants :\n";
while (<FORM>) {
	if (/^\"(......)\"\,/) {
		if (exists $allFormationInList{$1}) {
			$allFormationInList{$1}=1;
		} else {
			print $_, "\n";
		}
		
	}
}

print "\nFormations manquantes :\n";
while (my ($k, $v) =  each %allFormationInList) {
	unless ($v) {
		print $k,  "\n";
	}
}
