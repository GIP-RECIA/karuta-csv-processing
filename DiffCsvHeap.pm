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

	DEBUG! "colNoKey entete = $entete";
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
				return  do { $$line1[$i] cmp $$line2[$i] || next }  * $cpt;
			} 
			return $cpt;
		} 
		return - $cpt
	}
	return 0;
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
	while (my $ligne = $in->val) {
		$cout = addTas(scalar @tas, $ligne);
	}
	return (\@tas, $cout);
}

sub trieFile {
	my ($fileName, $origine, $destination, $nbFileHeader, @cle) = @_;

	my $heap = [];
	my $nbCle = @cle;
	my @colNoKey ;
	my $cout;
	
	my $in = DiffCsvReader->open($origine . $fileName);
	my $out = DiffCsvWriter->open($destination . $fileName);
	my $lastHeader;
	while ($nbFileHeader--) {
		$lastHeader = $in->pull();
		DEBUG! "nbFileHeader = $nbFileHeader;", @{$lastHeader};
		$out->push($lastHeader);
	}
	
	@colNoKey = colNoKey($lastHeader, @cle);
	($heap, $cout) = createHeap($in,  @cle, @colNoKey);

	for (@$heap) {
		$out->push($_);
	}
}

package DiffCsvReader ;

sub splitLine {
	my $line = shift;
	DEBUG! "splitLine : $line"; 
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
	$self->{file} = $desc;
	my $line = <$desc>;
	if ($line) {
		$self->{'line'} = splitLine($line);
		DEBUG! "premiere ligne $_", @{$self->{line}}; 
	} else {
		$self->{'line'} = $line;
	}
	
	return bless $self, $class;
}

sub val {
	my $self = shift;
	return  $self->{line};
}
sub pull{
	my $self = shift;
	
	my $line = $self->val;
	if ($line) {
		my $desc = $self->{file};
		if (<$desc>) {
			$self->{line} = splitLine($_);
			DEBUG! "line = $_, ";
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
	my $desc = $self->{file};
	if ($tabLine ) {
		my $line = join ($csvSep, @$tabLine);
		DEBUG! "print( $desc $line)" ;
		print( $desc $line);
	}; 
}
sub close {
	my $self = shift;
	close $self->{file};
}
