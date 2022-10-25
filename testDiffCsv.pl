#!/usr/bin/perl
use strict;
use utf8;
use open qw( :encoding(utf8) :std );

use FindBin;                    
use lib $FindBin::Bin;  

use MyLogger;

use DiffCsvHeap;

MyLogger::level(4, 2);
my $name1 = 'tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221012.csv';

#my $csv1 = DiffCsvReader->open($name1 . '.csv');
#my $sorted = DiffCsvWriter->open($name1 . '.sorted.csv');

trieFile($name1, './', './trier_', 3, 1, 3);




#DiffCsv::sort ($csv1, $sorted,  3, 1, 3);
#DiffCsv::sort ('tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221012.csv', 3, 1, 3);

__END__
my $name1 = 'tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221006';
my $name2 = 'tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221012';
my $csv1 = DiffCsvReader->open($name1 . '.csv');
my $csv2 = DiffCsvReader->open( $name2 . '.csv');
my $csvAdd = DiffCsvWriter->open( $name2 . '_add.csv');
my $csvSupp = DiffCsvWriter->open( $name1 . '_sup.csv');
my $csvDiff = DiffCsvWriter->open( $name2 . '_diff.csv');

DiffCsv::compareFile ($csv1, $csv2, $csvAdd, $csvSupp, $csvDiff, 3, 1, 3);
