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

#trieFile($name1, './', './trier_', 3,  3 );




#DiffCsv::sort ($csv1, $sorted,  3, 1, 3);
#DiffCsv::sort ('tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221012.csv', 3, 1, 3);


my $name2 = 'trier_tours_ETU_IUT TOURS_BUT_Tech_de_co_prc_SME_2A_2022_20221012.csv';

my $csv1 = DiffCsvReader->open($name1 );
my $csv2 = DiffCsvReader->open( $name2);
my $csvAdd = DiffCsvWriter->open( "add_$name1");
my $csvSupp = DiffCsvWriter->open( "sup_$name1");
my $csvDiff = DiffCsvWriter->open( "diff_$name1");

DiffCsv::compareFile ($csv1, $csv2, $csvAdd, $csvSupp, $csvDiff, 3, 3);
