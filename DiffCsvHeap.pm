#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );
 
use MyLogger;

my $csvSep = '","';


package DiffCsv;



#
sub colNoKey {
	my $entete = shift;
	my @cleeTab = @_;
	my @colUsed;
	for (@cleeTab) { $colUsed[$_]=1} ;
	@cleeTab = ();
	my $nbColEntete = @$entete;
	for (my $i = 0 ; $i < $nbColEntete; $i++) {
		unless ($colUsed[$i]) {
			push @cleeTab, $i; 
		}
	}
	return @cleeTab;
}

sub egalLigne {
	my $line1 = shift;
	my $line2 = shift;
	if (@$line1 == @$line2) {
		my $i;
		for ($i = 0; $i < @$line1; $i++) {
			return 0 if $$line1[$i] != $$line2[$i];
		}
		return $i;
	}
	return 0;
}
sub compareLigne {
	my $line1 = shift;
	my $line2 = shift;
	my @tab = @_;
	my $cpt = 0;
	foreach my $i (@tab) {
		$cpt++;
		if ($i < @$line1) {
			if ($i < @$line2) {
				$cpt =  do { $$line1[$i] cmp $$line2[$i] || next }  * $cpt;
			}
			return $cpt;
		}
		if ($i < @$line2) {
			return - $cpt;
		}
		return 0;
	}
	return 0;
}

sub createHeap {
	my ($in, @clee) = @_;
	my @tas;

	#ecriture du fichier dans un tableau;
	while (my $ligne = $in->pull) {
		push @tas, $ligne;
	}

	my $nbElem = @tas;
	my $cout = 0;
	for (my $noeud = int(($nbElem - 2)/2) ; $noeud >= 0 ; $noeud --) {
		$cout += &reorgTas(\@tas, $noeud, $tas[$noeud], $nbElem, @clee);
	}
	return (\@tas, $cout);
}

# utile pour le debug:
sub printHeap {
	my ($tas, $fin) = @_;
	my $nbCol = 1;

	print "\n";
	for (my $pos = 0; $pos < $fin ;) {
		my $col = 0 ;
		for (; $col < $nbCol && $pos < $fin ; $col++ ) {
			my $v = $$tas[$pos][3];
			 $v =~ s/TOUR//;
			print $pos++,":$v", "\t" x (int(48 / $nbCol)-1);
		}
		print "\n";
		$nbCol *= 2;
	}
}


sub reorgTas {
	my ($tas, $pos, $val, $fin, @clee)= @_;

	my $gauche =0;
	my $droit = 0;
	my $cout = 0;

	while ( ($droit =  $pos * 2 + 2) < $fin ) {
		$gauche = $droit -1 ;
		my $valG = $$tas[$gauche];
		my $valD = $$tas[$droit];
		$cout++;
		if ( compareLigne($valG, $valD, @clee) > 0) {
			$cout++;
			if (compareLigne($val, $valD, @clee) > 0) {
				$$tas[$pos] = $valD;
				$pos = $droit;
				next;
			} 
		} else {
			$cout++;
			if (compareLigne($val, $valG, @clee) > 0) {
				$$tas[$pos] = $valG;
				$pos = $gauche;
				next;
			}
		}
		$droit = $fin+1; #pour eviter le test apres la boucle
		last;
	}
	$gauche = $droit -1;
	if ($gauche < $fin) {
		my $valG = $$tas[$gauche];
		$cout++;
		if (compareLigne($val, $valG, @clee) > 0) {
			$$tas[$pos] = $valG;
			$pos = $gauche;
		} 
	}
	
	$$tas[$pos] =  $val;
	return $cout;
}



sub depileHeap {
	# depile tout le tas en ecrivant dans l'ordre et dans $out, renvoie le nombre de comparaisons
	my ($tas, $out, @clee) = @_;
	my $nbElem = @$tas;

	my $cout = 0 ;
	while (--$nbElem) {
		$out->push($$tas[0]);
		$$tas[0] = $$tas[$nbElem],
		$cout += reorgTas($tas, 0, $$tas[0], $nbElem, @clee);
	}
	$out->push($$tas[0]);
	return $cout;
}

sub trieFile {
	my ($fileName, $origine, $destination, $nbFileHeader, @cle) = @_;

	my $heap ;
	my $nbCle = @cle;
	my @colNoKey ;
	my $cout;
	
	my $in = DiffCsvReader->open($origine . $fileName);
	my $out = DiffCsvWriter->open($destination . $fileName);
	my $lastHeader;
	while ($nbFileHeader--) {
		$lastHeader = $in->pull();
		$out->push($lastHeader);
	}

	@colNoKey = colNoKey($lastHeader, @cle);
	($heap, $cout) = createHeap($in,  @cle, @colNoKey);

	INFO! "cout lecture = $cout";

	$cout += depileHeap($heap, $out, @cle, @colNoKey);
	INFO! "cout total= $cout";
	$in->close;
	$out->close;
}

# prend 2 DiffCsvReader à comparer; les 2 fichiers doivent être triés.
# et 3 DiffCsvWriter resultat
# les suppressions (ce qui est dans file1 mais pas dans file2)
# les ajouts (ce qui est dans file2 mais pas dans file1)
# les modifs (ce qui est dans file2 et dans file1 et  different) meme clé autre données differetes
# 
sub compareFile {
	my $f1 = shift; #2 file reader 
	my $f2 = shift;
	my $add = shift; #3 file writer
	my $supp = shift;
	my $diff = shift; 
	my $enteteSize = shift; # la taille des 1ere lignes a sauté
	my @cleeTab = @_; # les positions des champs clés dans l'ordre pour le trie

	my $entete ="";
	while ($enteteSize--) {
		if (!egalLigne ($f1->val, $f2->val)) {
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
				$diff->push($f1->pull);
				$diff->push($f2->pull);
				$diff->print("\n");
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

sub openAndCompareFile {
	my $name1 = shift; #2 fileName a comparer
	my $name2 = shift;
	my $nameAdd = shift; #3 fileName resultat
	my $nameSupp = shift;
	my $nameDiff = shift; 
	my $enteteSize = shift; # la taille des 1ere lignes a sauté
	my @cle = @_; # les positions des champs clés dans l'ordre pour le trie

	my $f1 = DiffCsvReader->open($name1);
	my $f2 = DiffCsvReader->open($name2);
	my $fAdd = DiffCsvWriter->open($nameAdd);
	my $fSupp = DiffCsvWriter->open($nameSupp);
	my $fDiff = DiffCsvWriter->open($nameDiff);
	compareFile($f1, $f2, $fAdd, $fSupp, $fDiff, $enteteSize, @cle);
}
package DiffCsvReader ;

sub splitLine {
	my $line = shift;
	if ($line) {
		my @line = split ($csvSep, $line);
		return \@line;
	}
	return 0;
}

sub open {
	my ($class, $fileName) = @_;
	my $self = {
		fileName => $fileName,
		line => 0,
		file => 0,
	};
	my $desc;
	open ($desc, $fileName) || FATAL! "read $fileName : $!";
	$self->{'file'} = $desc;
	my $line = <$desc>;
	if ($line) {
		$self->{'line'} = splitLine($line);
	} else {
		$self->{'line'} = $line;
	}
	
	return bless $self, $class;
}

sub val {
	my $self = shift;
	return  $self->{'line'};
}
sub pull{
	my $self = shift;
	
	my $line = $self->val;
	if ($line) {
		my $desc = $self->{'file'};
		my $next = <$desc>;
		if ($next) {
			$self->{line} = splitLine($next);
		} else {
			$self->{line} = 0;
		}
		
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
	my ($self, $tabLine) = @_;
	my $desc = $self->{'file'};
	if ($tabLine ) {
		my $line = join ($csvSep, @$tabLine);
		print( $desc $line);
	}; 
}

sub print {
	my ($self, $string) = @_;
	my $desc = $self->{'file'};
	if ($string) {
		print( $desc $string);
	}
}
sub close {
	my $self = shift;
	close $self->{file};
}
