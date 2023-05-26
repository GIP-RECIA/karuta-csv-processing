#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

use MyLogger;

package DiffCsv;


my $csvSep = '","';


sub sort {
	my $in = shift; # DiffCsvReader
	my $out = shift; # DiffCsvWriter
	my $enteteSize = shift;
	my @cleeTab = @_; # tableau des cles donne les indices des clees du csv

	my @data;
	my $lineNo = 0;
	my $lastEntete; 
	while ($enteteSize--) {
		$out->push($lastEntete = $in->pull);
	}

	while ($in->val) { push (@data, $in->pull);}
	$in->close;
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
	for (&$trier) {$out->push($_)}
	$out->close;
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

 
# prend 2 DiffCsvReader à comparer les 2 fichiers doivent être triés.
# et 3 DiffCsvWriter
# resultat  :
# les suppressions (ce qui est dans file1 mais pas dans file2)
# les ajouts (ce qui est dans file2 mais pas dans file1)
# les modifs (ce qui est dans file2 et dans file1 et  different) suppose une notion de clé
# 
sub compareFile {
	my $f1 = shift; #2 file reader 
	my $f2 = shift;
	my $add = shift; #3 file writer
	my $supp = shift;
	my $diff = shift; 
	my $enteteSize = shift; # la taille des 1ere lignes a sauté
	my @cleeTab = @_; # les positions des champs dans l'ordre pour le trie

	my $entete ="";
	while ($enteteSize--) {
		if ($f1->val ne $f2->val) {
			$diff->push($f1->val);
			$diff->push($f2->val);
		}
		$entete = $f1->val;
		$supp->push($f1->pull);
		$add->push($f2->pull);
	}
	
	my @colNoKey = colNoKey($entete, @cleeTab);
	my $cleSize = @cleeTab;
	
	while ($f1->val && $f2->val) {
		my $cmp = compareLigne($f1->val, $f2->val, @cleeTab, @colNoKey);
		if ($cmp) {
			# Les lignes sont differentes
			if (abs($cmp) > $cleSize) {
				# avec la même clé.
				$diff->push($f1->pull, $f2->pull);
			} elsif ($cmp < 0) {
				# line1 avant line2 => line1 supprimé
				$supp->push($f1->pull);
			} else {
				# line2 avant line1 => line2 ajouté
				$add->push($f2->pull);
			}
		} else {
			# ligne inchangée;
			$f1->pull;
			$f2->pull;
		}
	}
	while ($f1->val) {
		$supp->push($f1->pull);
	}
	while ($f2->val) {
		$add->push($f2->pull);
	}
}

package DiffCsvReader ;
sub open {
	my ($class, $fileName) = @_;
	my $self = {
		fileName => $fileName,
		line => 0,
		file => 0,
	};
	my $desc;
	open ($desc, $fileName) || FATAL! "read $fileName : $!";
	$self->{file} = $desc;
	$self->{line} = <$desc>;
	return bless $self, $class;
}
sub val {
	my $self = shift;
	return  $self->{line};
}
sub pull{
	my $self = shift;
	my $line = $self->{line};
	if ($line) {
		my $desc = $self->{file};
		$self->{line} = <$desc>;
	}
	return $line;
}
sub close {
	my $self = shift;
	close $self->{file};
}

package DiffCsvWriter ;
sub open {
	my ($class, $fileName) = @_;
	my $self = {
		fileName => $fileName,
		file => 0,
	};
	my $desc;
	open ($desc, ">$fileName") || FATAL! "write $fileName : $!";
	$self->{file} = $desc;
	return bless $self, $class;
}
sub push {
	my ($self, @lines) = @_;
	my $desc = $self->{file};
	for (@lines ) { print( $desc $_) }; 
}
sub close {
	my $self = shift;
	close $self->{file};
}

1;
