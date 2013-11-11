#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $datafile = shift;

die "Please provide a filename to read\n"
    unless $datafile;

open(DATA_FILE, $datafile) || die "Can't open $datafile!\n";

while(my $churn_line = <DATA_FILE>) {
	chomp $churn_line;
	if ($churn_line =~ m{^(\d+)\s+(.*)} ) {
		my $frequency= $1;
		my $filename = $2;
		print $filename ."\t\t(" .$frequency .")\n";
	} else {
		print "err> $churn_line\n";
	}
}

close DATA_FILE;