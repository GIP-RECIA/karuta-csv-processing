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

	my @entete ;
	my @data;
	rename ($file, "$file.org") || FATAL! "mv $file, $file.org " . $!;
	open (OUT , ">$file")  || FATAL! "write $file " . $!;  
	open (IN , "$file.org") || FATAL! "$file " .$!;
	my $lineNo = 0;
	my $lastEntete;
	while (<IN>) {
		if ($lineNo++ < $enteteSize) {
			print OUT;
			$lastEntete = $_;
		} else {
			push (@data, $_);
		}
	}
	close IN;

	my $trier;
	if (@cleeTab) {
		if ($lastEntete) {
			INFO! $lastEntete;
			my @colUsed;
			map ({ $colUsed[$_]=1;} @cleeTab);
			my $nbColEntete = split $csvSep, $lastEntete;
			for (my $i = 0 ; $i < $nbColEntete; $i++) {
				unless ($colUsed[$i]) {
					push @cleeTab, $i; 
				}
			}
			
			DEBUG! map({"$_ "} @cleeTab) ;
		}
		$trier = sub {sort {&compareLigne($a, $b, @cleeTab)} @data};
	} else {
		$trier = sub {sort(@data)};
	}
	map({print (OUT $_);} &$trier );
	close OUT;
}

sub compareLigne {
	my @line1 = split $csvSep, shift;
	my @line2 = split $csvSep, shift;
	my @tab = @_;
	foreach my $i (@tab) {
		my $res;
		if ($i < @line1) {
			if ($i < @line2) {
				$res = $line1[$i] cmp $line2[$i];
				TRACE! "$res = $line1[$i] cmp $line2[$i]";
			} else {
				$res =  1;
			}
		} elsif ($i < @line2) {
			$res = -1;
		}
		if ($res) {
			return $res;
		}
	}
	return 0;
}

1;
