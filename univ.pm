

package Univ;

my %UNIVS;

sub new {
	my ($class, $id, $ftpRep, $path, $filePrefix, $zipfilePrefix) = @_;
	unless ($zipfilePrefix) {
		$zipfilePrefix = $filePrefix;
	}
	my $self = {
		id => $id,
		ftpRep => $ftpRep,
		path => "$path/$filePrefix",
		zipPrefix => $zipFilePrefix,
		filePrefix => $filePrefix,
	};
	bless $self, $class;
	
	$UNIVS{$id} = $self;

	return $self
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
		$self->{prefix} = shift;
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
1;
