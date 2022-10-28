#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );
#use FindBin;                    
#use lib $FindBin::Bin;  

use MyLogger;


my $csvSep = '","';




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
		} else {
			$cpt =  - $cpt;
		}
		last;
	}
	return $cpt;
}

sub createHeap {
	my ($in, @clee) = @_;
	
	my @tas;

	sub addTas {
		my ($pos, $val) = @_;
		
		if ($pos > 0) {
			# on est sur un fils gauche
			# on regarde si le pere est plus grand
			my $pere = int ($pos / 2);
			my $valPere = $tas[$pere];

			if ( compareLigne($valPere, $val, @clee) > 0) {
				$tas[$pos] = $valPere;
				return 1 + addTas($pere, $val, @clee);
			}
			$tas[$pos] = $val;
			return 1;
		}
		$tas[$pos] = $val;
		return 0;
	}

	my $cout = 0;
	while (my $ligne = $in->pull) {
		$cout += addTas(scalar(@tas), $ligne);
	}
	return (\@tas, $cout);
}

sub depileHeap {
	# depile tout le tas en ecrivant dans l'ordre et dans $out, renvoie le nombre de comparaisons
	my ($tas, $out, @clee) = @_;
	my $nbElem = @$tas;

	my $cout = 0 ;

	sub reorgTas {
		# la sommet est libre et on insert val dans le tas , il faut la mettre à la bonne place
		# on doit se retrouver avec le min du tas au sommet.
		my ($tas, $pos, $val, $fin)= @_;

		my $res = $val;
		my $gauche = $pos * 2 + 1;
		my $droit = $gauche + 1;
		if ( $droit < $fin ) {
			my $valG = $$tas[$gauche];
			my $valD = $$tas[$droit];

			$cout++;
			if ( compareLigne($valG, $valD, @clee) > 0) {
				$cout++;
				if (compareLigne($val, $valD, @clee) > 0) {
					$res = $valD;
					reorgTas($tas, $droit, $val, $fin);
				}
			} else {
				$cout++;
				if (compareLigne($val, $valG, @clee) > 0) {
					$res = $valG;
					reorgTas($tas, $gauche, $val, $fin);
				}
			}
		} elsif ($gauche < $fin) {
			my $valG = $$tas[$gauche];
			$cout++;
			if (compareLigne($val, $valG, @clee) > 0) {
				$res = $valG;
				reorgTas($tas, $gauche, $val, $fin);
			}
		}
		return $$tas[$pos] = $res;
	}

	while ($nbElem--) {
		$out->push($$tas[0]);
		reorgTas($tas, 0,  $$tas[$nbElem], $nbElem);
	}
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

sub close {
	my $self = shift;
	close $self->{file};
}
