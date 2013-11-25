#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw( dirname basename );
use File::Spec::Functions qw( catfile path curdir abs2rel rel2abs );
use Cwd qw( abs_path cwd );
use Data::Dumper;

use Switch;

my $target_dir   = $ARGV[0] if defined($ARGV[0]);
our $working_dir = cwd();
our $output_dir = "churn-complexity-output";

my $dirnames     = dirname(rel2abs($target_dir, $working_dir));
my $target_name  = basename($target_dir);
my $result_dir   = "$output_dir$dirnames/$target_name";

# Define global scope for referencing from each Comparator
my %risky_items = ();

sub get_git_repo_list {
	my $git_repo_list_filepath = catfile($working_dir, "git-repo-list");

	open(GIT_REPO_LIST, '<:encoding(UTF-8)', $git_repo_list_filepath)
		or die "Couldn't open 'git-repo-list': $1\n";

	my @git_repo_list = ();
	while(my $git_path_line = <GIT_REPO_LIST>) {
		chomp $git_path_line;
		push @git_repo_list, $git_path_line;
	}
	close GIT_REPO_LIST;
	return @git_repo_list;
}

# read 'file-count'	and get value
# if there doesn't exist file-count, return value is -1 (negative).
sub get_items_count {
	my ($repo_path) = shift @_;
	my $count = 0;
	my $file_count_path = catfile($output_dir, $repo_path, "file-count");

	open(COUNT_FILE, '<', $file_count_path) or return -1;
 	my @lines = <COUNT_FILE>;
 	chomp $lines[0];
 	$count = $lines[0];
 	close (COUNT_FILE);

 	#print "$file_count_path : $count\n";
 	return int($count);
}

sub min_ ($$) {
	my ($a, $b) = @_;
	if ($a < $b) { return $a; }
	else { return $b; }
}

sub readline_max_complexity {
	my ($line, $repo_path, $risky_items) = @_;

	# filename, max function name, commits, max complexity, file complexity, # of function, avg complexity
	if ($line =~ m{^(.+),\s+(.+),\s+(\d+),\s+(\d+),\s+(\d+),\s+(\d+),\s+(\d+\.\d+)} ) {
		my $filename          = $1;
		my $max_function_name = $2;
		my $commits           = $3;
		my $max_complexity    = $4;
		my $file_complexity   = $5;
		my $nb_of_function    = $6;
		my $avg_complexity    = $7;

#		my $key = $repo_path ."::" .$filename ."::" .$max_function_name;
		my $key = $repo_path ."::" .$filename ."::" .$max_function_name ."($commits, $max_complexity)";
		$risky_items->{$key}{'repo_path'}         = $repo_path;
		$risky_items->{$key}{'filename'}          = $filename;
		$risky_items->{$key}{'commits'}           = int($commits);
		$risky_items->{$key}{'file_complexity'}   = int($file_complexity);
		$risky_items->{$key}{'avg_complexity'}    = $avg_complexity;
		$risky_items->{$key}{'max_function_name'} = $max_function_name;
		$risky_items->{$key}{'max_complexity'}    = int($max_complexity);
		$risky_items->{$key}{'avg_complexity'}    = $avg_complexity;
#			print $count,") ", $line,"\n";
	}
}

sub readline_file_complexity {
	my ($line, $repo_path, $risky_items) = @_;

	# filename, commits, file complexity, # of function, avg complexity, max function name, max complexity
	if ($line =~ m{^(.+),\s+(\d+),\s+(\d+),\s+(\d+),\s+(\d+\.\d+),\s+(.+),\s+(\d+)} ) {
		my $filename          = $1;
		my $commits           = $2;
		my $file_complexity   = $3;
		my $nb_of_function    = $4;
		my $avg_complexity    = $5;
		my $max_function_name = $6;
		my $max_complexity    = $7;

#		my $key = $repo_path ."::" .$filename;
		my $key = $repo_path ."::" .$filename ."($commits, $file_complexity)";
		$risky_items->{$key}{'repo_path'}         = $repo_path;
		$risky_items->{$key}{'filename'}          = $filename;
		$risky_items->{$key}{'commits'}           = int($commits);
		$risky_items->{$key}{'file_complexity'}   = int($file_complexity);
		$risky_items->{$key}{'avg_complexity'}    = $avg_complexity;
		$risky_items->{$key}{'max_function_name'} = $max_function_name;
		$risky_items->{$key}{'max_complexity'}    = int($max_complexity);
		$risky_items->{$key}{'avg_complexity'}    = $avg_complexity;
#			print $count,") ", $line,"\n";
	}
}

#  next if value is 0 
# if value >= 10
#   file_churn_complexity.csv 에서 10 개 읽어들임
# else # value < 10
#   file_churn_complexity.csv 에서 value 만큼만 읽어들임
# 읽어들인 내용을 hash %risky_items 에 저장
sub read_top_items {
	my ($criteria, $repo_path, $limit, $risky_items) = @_;
	my $count = 0;
	my $filename = "file_churn_complexity.csv";
	if ($criteria eq "max") {
		$filename = "file_churn_complexity_max.csv";
	}

	my $file_churn_complexity_file_path = catfile($output_dir, $repo_path, $filename);

	open(FILE_CHURN_COMPLEXITY, '<:encoding(UTF-8)', $file_churn_complexity_file_path)
		or die "Couldn't open '$filename': $1\n";

	while(my $line = <FILE_CHURN_COMPLEXITY>) {
		last if $count > $limit;

		chomp $line;

		switch($criteria) {
			case "max"  { 
				readline_max_complexity($line, $repo_path, $risky_items);
			}
			else        {
				readline_file_complexity($line, $repo_path, $risky_items);
			}
		}
		$count++;
	}
#	print Dumper \$risky_items{$repo_path};
	close FILE_CHURN_COMPLEXITY;
	return $count;
}

sub top_items_of_all_repo {
	my ($criteria, $git_limit, @git_repo_list) = @_;
	my %risky_items = ();

	my $count = 0;
	foreach my $git_repo (@git_repo_list) {
		my $items_count = get_items_count($git_repo);
		$count++;
		next if $items_count <= 0;
#		print "$count) $git_repo : ", min_($items_count, $git_limit) ," of $items_count \n";
		read_top_items($criteria, $git_repo, min_($items_count, $git_limit), \%risky_items);
	}
	return %risky_items;
}

# Comparator
sub by_avg_complexity {
	( $risky_items{$b}{'commits'} <=> $risky_items{$a}{'commits'} )
		or
	( $risky_items{$b}{'avg_complexity'} <=> $risky_items{$a}{'avg_complexity'} )
		or
	( lc $risky_items{$a}{'repo_path'} cmp lc $risky_items{$b}{'repo_path'} )
		or 
	( lc $risky_items{$a}{'filename'} cmp lc $risky_items{$b}{'filename'} )
}

sub by_max_complexity {
	( $risky_items{$b}{'commits'} <=> $risky_items{$a}{'commits'} )
		or
	( $risky_items{$b}{'max_complexity'} <=> $risky_items{$a}{'max_complexity'} )
		or
	( lc $risky_items{$a}{'max_function_name'} cmp lc $risky_items{$b}{'max_function_name'} )
		or
	( lc $risky_items{$a}{'repo_path'} cmp lc $risky_items{$b}{'repo_path'} )
		or 
	( lc $risky_items{$a}{'filename'} cmp lc $risky_items{$b}{'filename'} )
}

sub by_file_complexity {
	( $risky_items{$b}{'commits'} <=> $risky_items{$a}{'commits'} )
		or
	( $risky_items{$b}{'file_complexity'} <=> $risky_items{$a}{'file_complexity'} )
		or
	( lc $risky_items{$a}{'repo_path'} cmp lc $risky_items{$b}{'repo_path'} )
		or 
	( lc $risky_items{$a}{'filename'} cmp lc $risky_items{$b}{'filename'} )
}

sub build_csv_header {
	my ($criteria) = @_;

	my $header = "repo_name, filename";
	if ($criteria eq "max") {
		$header .= ", function name";
	}

	$header .= ", commits";
	if ($criteria eq "max") {
		$header .= ", function complexity";
	}
	$header .= ", file complexity, avg complexity\n"; 

	return $header;
}

sub build_csv_data {
	my ($key, $criteria, $risky_items) = @_;

	my $data = "$risky_items->{$key}{'repo_path'}"
	      . ", $risky_items->{$key}{'filename'}";

	if ($criteria eq "max") {
		$data .= ", $risky_items->{$key}{'max_function_name'}"; 
	}

	$data .= ", $risky_items->{$key}{'commits'}";
	if ($criteria eq "max") {
		$data .= ", $risky_items->{$key}{'max_complexity'}"; 
	}
	$data .= ", $risky_items->{$key}{'file_complexity'}"
		  . ", $risky_items->{$key}{'avg_complexity'}\n"; 
	return $data;
}

sub export_top_risk_to_csv {
	my ($criteria, $result_limit, $top_risk_filepath, $risky_items) = @_;
	my $i = 1;
	my @key_list = ();

	switch($criteria) {
		case "max"  { @key_list = sort by_max_complexity  keys %{$risky_items}; }
		case "avg"  { @key_list = sort by_avg_complexity  keys %{$risky_items}; }
		else        { @key_list = sort by_file_complexity keys %{$risky_items}; }
	}

#	print Dumper \@key_list;

	open(TOP_RISK_FILE, '>:encoding(UTF-8)', $top_risk_filepath)
		or die "Couldn't open 'top_risk_file.csv': $1\n";

	print TOP_RISK_FILE build_csv_header($criteria);
	foreach my $key (@key_list) {
		last if $i++ > $result_limit;

		print TOP_RISK_FILE build_csv_data($key, $criteria, $risky_items);
	}

	close TOP_RISK_FILE;
	#print Dumper \%{$risky_items};
	return $i;
}

# ====================================================================

my $criteria = "file";
$criteria = lc $ARGV[1] if defined($ARGV[1]);
my $git_limit = 10;
my $result_limit = 20;
$result_limit = $ARGV[2] if defined($ARGV[2]);

my $result_filename = "top_".$result_limit."_risk_files(".$criteria.").csv";
my $top_risk_filepath = catfile($result_dir, $result_filename);

#   파라미터에 따라 "file", "max" 저장되는 값이 달라짐
# churn-complexity 순으로 정렬하고 상위 20 개만 top-20-risk-list(...) 파일에 저장
#   사용자의 파라미터에 따라 파일이름의 끝은 "file", "max" 로 마침

my $HIGHLIGHT="\e[01;34m";
my $NORMAL="\e[00m";

print $HIGHLIGHT,"================================================================================", "$NORMAL\n";
print $HIGHLIGHT," Screening top $result_limit risk list ($criteria)", "$NORMAL\n";
print $HIGHLIGHT,"================================================================================", "$NORMAL\n";
print $HIGHLIGHT,"1/3) Retrieving all git repository list", "$NORMAL\n";
my @git_repo_list = get_git_repo_list();
print "   => total ", $HIGHLIGHT, scalar @git_repo_list, "$NORMAL repos identified.\n";
print $HIGHLIGHT,"2/3) Screening top risk items from all git repositories", "$NORMAL\n";
%risky_items = top_items_of_all_repo($criteria, $git_limit, @git_repo_list);
print "   => total ", $HIGHLIGHT, scalar keys %risky_items, "$NORMAL items acquired.\n";
print $HIGHLIGHT,"3/3) Exporting top $result_limit risk items", "$NORMAL\n";
export_top_risk_to_csv($criteria, $result_limit, $top_risk_filepath, \%risky_items);
print "   See result at ", $HIGHLIGHT, "'$top_risk_filepath'$NORMAL file.\n";
print $HIGHLIGHT,"Done...", "$NORMAL\n";
