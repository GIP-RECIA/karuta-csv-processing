#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

#use FindBin;                    
#use lib $FindBin::Bin;  

use MyLogger;

package DiffCsv;

my $csvSep = '","';

sub sort {
	my $file = shift;
	my $enteteSize = shift;
	my @cleeTab = @_; # tableau des cles donne les indices des clees du csv
	my $IN;
	my $OUT;
	my @entete ;
	my @data;
	rename ($file, "$file.org") || FATAL! "mv $file, $file.org " . $!;
	
	open ($OUT , ">$file")  || FATAL! "write $file " . $!;  
	open ($IN , "$file.org") || FATAL! "$file " .$!;

	my $lineNo = 0;

	my $lastEntete = &copieEntete($IN, $OUT, $enteteSize);
	
	while (<$IN>) { push (@data, $_); }
	
	close $IN;

	my $trier;
	
	if (@cleeTab) {
		my @colAutre = ();
		if ($lastEntete) {
			INFO! $lastEntete;
			@colAutre = &colNoKey($lastEntete, @cleeTab);
			DEBUG! map({"$_ "} @cleeTab) ;
		}
		$trier = sub {sort {&compareLigne($a, $b, @cleeTab, @colAutre)} @data};
	} else {
		$trier = sub {sort(@data)};
	}
	map({print ($OUT $_);} &$trier );
	close $OUT;
}

sub copieEntete {
	my $in = shift;
	my $out = shift;
	my $cpt = shift;
	my $last;
	while ($cpt--) {
		$last = <$in>;
		print $out $last;
	}
	return $last;
}

sub colNoKey {
	my $entete = shift;
	my @cleeTab = @_;
	my @colUsed;
		for (@cleeTab) { $colUsed[$_]=1} ;
		@cleeTab = ();
		my $nbColEntete = split $csvSep, $entete;
		for (my $i = 0 ; $i < $nbColEntete; $i++) {
			unless ($colUsed[$i]) {
				push @cleeTab, $i; 
			}
		}
	return @cleeTab;
}

sub compareLigne {
	my @line1 = split $csvSep, shift;
	my @line2 = split $csvSep, shift;
	my @tab = @_;
	my $cpt = 0;
	foreach my $i (@tab) {
		$cpt++;
		if ($i < @line1) {
			if ($i < @line2) {
				return  do { $line1[$i] cmp $line2[$i] || next }  * $cpt;
			} 
			return $cpt;
		} 
		return - $cpt
	}
	return 0;
}

 
# renvoie 3 tableaux des differences:
# les suppressions (ce qui est dans file1 mais pas dans file2)
# les ajouts (ce qui est dans file2 mais pas dans file1)
# les modifs (ce qui est dans file2 et dans file1 et  different) suppose une notion de clé
# on suppose les 2 fichiers triés.
sub compareFile {
	my $file1 = shift;
	my $file2 = shift;
	my $enteteSize = shift;
	my @cleeTab = @_;

	my $add = $file2;
	$add =~ s/.csv$/_add.csv/ || FATAL! "$file2 not csv file";
	my $sup = $file1;

	$sup =~ s/.csv$/_sup.csv/ || FATAL! "$file1 not csv file";

	my ($IN1,$IN2,$ADD, $SUP);
	open $IN1, "$file1" || FATAL! "read $file1 : $!";
	open $IN2, "$file2" || FATAL! "read $file2 : $!";

	open $ADD, ">$add" || FATAL! "read $add : $!";
	open $SUP, ">$sup" || FATAL! "read $sup : $!";


	my $entete = copieEntete($IN1, $SUP, $enteteSize);

	if (copieEntete($IN2, $ADD, $enteteSize) eq $entete) {
		my @colNoKey = colNoKey($entete, @cleeTab);
		my $in1 = <$IN1>;
		my $in2 = <$IN2>;
		while ($in1 && $in2) {
			my $cmp = compareLigne($in1, $in2, @cleeTab, @colNoKey);
			if ($cmp) {
				# cas les lignes sont differentes
				if (abs($cmp) > @cleeTab) {
					# cas on la clee est la même, c'est une modif
					print "-+ $in1";
					print "+- $in2\n";
					$in1 = <$IN1>;
					$in2 = <$IN2>;
				} elsif ($cmp < 0) {
					# in1 vient avant in2 donc in1 à été supprimé
					print $SUP $in1;
					print "-- $in1\n";
					$in1 = <$IN1>; 
				} else {
					# in2 vient avant in1 donc in2 à été ajouté
					print $ADD $in2;
					print "++ $in2\n";
					$in2 = <$IN2>;
				}
			} else {
				# même 2 lignes
				$in1 = <$IN1>;
				$in2 = <$IN2>;
			}
		}
		while ($in1) {
			print $SUP $in1;
			$in1 = <$IN1>; 
		};
		while ($in2) {
			print $ADD $in2;
			$in2 = <$IN2>;
		}
	}
}

1;
