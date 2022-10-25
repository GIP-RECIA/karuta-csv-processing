

package Univ;

my %UNIVS;

sub new {
	my ($class, $id, $ftpRep, $path, $filePrefix, $zipFilePrefix) = @_;
	unless ($zipFilePrefix) {
		$zipFilePrefix = $filePrefix;
	}
	my $self = {
		id => $id,
		ftpRep => $ftpRep,
		path => $path,
		zipPrefix => $zipFilePrefix,
		filePrefix => $filePrefix,
		sepChar => ','
	};
#	bless $self, $class;
	if ($id eq "orleans") {
		$self->{filtreEtap} =
			sub {
				return map({ s/^(\S{3})\S/\1I/; $_; }  @_);
			} ;
	}
	
	$UNIVS{$id} = $self;

	return bless $self, $class;
}

sub id {
	my $self = shift;
	return $self->{id};
}

sub path {
	my $self = shift;
	if (@_ > 0) {
		$self->{path} = shift;
	}
	return $self->{path} ;
}

sub ftpRep {
	my $self = shift;
	if (@_ > 0) {
		$self->{ftpRep} = shift;
	}
	return $self->{ftpRep} ;
}

sub prefix {
	my $self = shift;
	if (@_ > 0) {
		$self->{filePrefix} = shift;
	}
	return $self->{filePrefix} ;
}

sub zipPrefix {
	my $self = shift;
	if (@_ > 0) {
		$self->{zipPrefix} = shift;
	}
	return $self->{zipPrefix} ;
}
sub all {
	return values %UNIVS;
}

sub getById {
	my $class = shift;
	return $UNIVS{shift()};
}

sub sepChar {
	my $self = shift;
	if (@_ > 0) {
		$self->{sepChar} = shift;
	}
	return $self->{sepChar} ;
}

1;
