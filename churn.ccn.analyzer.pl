#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec::Functions qw( catfile path );
use Data::Dumper;

# ======================== USER CUSTOMIZING DATA ====================
our $output_dir = "churn-complexity-output";

our %language_patterns = (
	"default" => 'h|hh|hpp|c|cc|cxx|cpp|java|js',
	#"c++" => 'h|hh|hpp|c|cc|cxx|cpp',
	"c++" => 'c|cc|cpp',
	"java" => 'java',
	"web" => 'js|php|html|css',
	"null" => '',
);
# ======================== USER CUSTOMIZING DATA ====================

use constant PATH => path;
use constant PATHEXT => split /;/, $ENV{PATHEXT};

sub which {
	my $name = shift;

	grep { -e } map { my $file = $_; 
		map { catfile $_, $file } PATH
		} 
		map { $name . lc $_ } (q{}, PATHEXT);
}

sub check_prerequisite($) {
	my $target_dir = shift(@_);

	if (! -d $target_dir) {
		print "\n\tTarget directory('$target_dir') is not exists!\n";
		return "";
	}

	if (! -d "$output_dir/$target_dir") {
		make_path "$output_dir/$target_dir";
	}

	my $und_exists = which('und');
	if (!$und_exists) {
		print "You should install Understand and add path on your PATH\n";
		return "";
	} 

	chdir $target_dir
    or die "Failed to enter the specified directory '$target_dir': $!\n";
	if (! -d ".git") {
		print "'$target_dir' is not a git repository!\n";
		return "";
	}
	chdir "..";
	return 1;
}

sub build_und_database($$) {
	my ($target_dir,$languages) = @_;

#	chdir $target_dir;
	my $BUILD_DATABASE_COMMAND = "und -quiet "
	."create -db $output_dir/$target_dir/$target_dir.udb -languages $languages "
	."-JavaVersion java6 "
	."add "
		."-exclude .git "
		."-subdir on $target_dir "
	."settings "
#		."-WriteColumnTitles on "
#		."-ShowDeclaredInFile on "
#		."-FileNameDisplayMode NoPath "
#		."-DeclaredInFileDisplayMode RelativePath "
		 ."-metrics "
		 	."CountLineCodeExe "
		 	."Cyclomatic "
		 	."MaxCyclomatic "
		 	."MaxNesting "
		 ."-metricsOutputFile $output_dir/$target_dir/metrics.csv";
#	print "$BUILD_DATABASE_COMMAND\n";	
	system($BUILD_DATABASE_COMMAND);

	my $ANALYZE_DATABASE_COMMAND = 
		"und -quite analyze -db $output_dir/$target_dir/$target_dir.udb";

	if ( ! open(ANALYZE_DATABASE,'-|', $ANALYZE_DATABASE_COMMAND) ) {
	    die "Failed to process 'und analyze -db $output_dir/$target_dir/$target_dir.udb': $!\n";
	}
	while(my $db_analysis = <ANALYZE_DATABASE>) {
		chomp $db_analysis;
		if ($db_analysis =~ m{Errors:(\d+)\s+Warnings:(\d+)} ) {
			print "... $db_analysis\n";
		}
	}
#	system("und -quite analyze -db $output_dir/$target_dir.udb");
#	system("und -quite metrics -db $output_dir/$target_dir.udb");
#	chdir "..";
}

# chdir "git";

# my $COMMIT_FREQUENCY_COMMAND = 
# 'git rev-list --since=\'one month ago\' --no-merges --objects --all | 
# grep -E \'' .$languages{"cpp"} .'\' | 
# awk \'"" != $2\' | sort -k2 | uniq -cf1 | sort -rn';

# if ( ! open(GIT_REV_LIST,'-|', $COMMIT_FREQUENCY_COMMAND) ) {
#     die "Failed to process 'git rev-list': $!\n";
# }

# my %file_stats;
# my %function_complexities;
# my $count = 1;
# while(my $churn_line = <GIT_REV_LIST>) {
# 	chomp $churn_line;
# 	if ($churn_line =~ m{^\s+(\d+)\s+(.*)\s+(.*)} ) {
# 		my $frequency= $1;
# 		my $sha1     = $2;
# 		my $filename = $3;

# 		my $type = `git cat-file -t $sha1`;
# 		chomp $type;
# 		if ("blob\n" eq $type) {
# 			#print "$count\t $filename\t ($frequency commits)\n";
# 			$file_stats{$filename}{commits} = $frequency;
# 		}
# 	} else {
# 		print "err> $churn_line\n";
# 	}
# 	$count++;
# }
# #print Dumper \%file_stats;
# print "total files : " .keys %file_stats;

# close GIT_REV_LIST;

# 10) �경 �인
#     : check_prerequisite
#   11) und �행�일PATH �에 존재�는지 �인�다.
#   12) �재 �더가 git repository �� �인�다. (.git �더 �무 검
# 20) �치und �이�베�스륝성�다. (.udb �일)
#     : build_und_database
#   21) und �이�베�스 �성
#   22) �팅�보 �정 (�코 �어, 메트� �정)
#   23) und �이�베�스�일 추� & 분석
# 30) git �서 최근 간의 �일 커밋 빈도�측정�다.
#     : get_file_churn
#   31) �일커밋 빈도륌일��한 (중간 �출�
# 40) udb �서 �일 �수복잡�� LOC, �일복잡�� 측정�다.
#     : build_churn_complexity(filepath)
#   41) 20) �서 �� �일 �보�에 �.. (모든 �일�요�음)
# 50) ��된 �이�� ��일(�� csv �맷�로)��한
#     : export_file_churn_to_csv
# 60) ��된 �보�바탕�로 file-churn-complexity chart 륝성�다.
#     : draw_chart
#   61) perl 롘들�면 python �로 차트륝성�자.

sub get_file_churn($\@;$) {
	my ($target_dir, $languages, $since) = @_;

	chdir $target_dir;

	my $since_str = "";
	$since_str = '--since=\'' .$since .'\'' if defined $since;

	my $COMMIT_FREQUENCY_COMMAND = 
	'git rev-list ' .$since_str .' --no-merges --objects --ignore-missing --all | 
	grep -E \'*\.(' .get_language_pattern_str($languages) .')$\' | 
	awk \'"" != $2\' | sort -k2 | uniq -cf1 | sort -rn |
	while read frequency sha1 path 
	do 
		[ "blob" = "$(git cat-file -t $sha1)" ] && echo -e "$frequency\t$path"; 
	done';

#	print "$COMMIT_FREQUENCY_COMMAND\n";

	if ( ! open(GIT_REV_LIST,'-|', $COMMIT_FREQUENCY_COMMAND) ) {
	    die "Failed to process 'git rev-list': $!\n";
	}

	my %file_stats;
	while(my $churn_line = <GIT_REV_LIST>) {
		chomp $churn_line;
		if ($churn_line =~ m{^(\d+)\s+(.+)} ) {
			my $frequency= $1;
			my $filename = $2;

#			print ".";
#			print "$filename\t ($frequency commits)\n";
			$file_stats{$filename}{commits} = $frequency;
		} else {
			print "err> $churn_line\n";
		}
	}
	my $number_of_items = keys %file_stats;

	close GIT_REV_LIST;	
	chdir "..";
	return %file_stats;
}

sub export_file_churn_to_csv {
	my ($target_dir, %file_stats) = @_;

	my $file_churn_file_path = catfile("$output_dir/$target_dir", "file_churn.csv");
	open(FILE_CHURN, '>:encoding(UTF-8)', $file_churn_file_path)
		or die "Couldn't open 'file_churn.csv': $1\n";

	print FILE_CHURN "filename, commits\n";
	# sort 1) commits desc 2) filename asc with lowercase
	foreach (sort {($file_stats{$b}{commits} <=> $file_stats{$a}{commits}) or
		           (lc $a cmp lc $b)} keys %file_stats ) {
#		print "$_ : $file_stats{$_}{commits}\n";
		print FILE_CHURN "$_, $file_stats{$_}{commits}\n";
	}
	close FILE_CHURN;
	#print Dumper \%file_stats;
}

sub to_languages_array($) {
	my $language_str = shift(@_);
	return split('\s+', $language_str);
}

sub get_language_list_str (\@) {
	my ($languages) = shift(@_);
	return join " ", @{$languages};
}

sub get_language_pattern_str (\@) {
	my ($languages) = shift(@_);

	my $pattern_str = "";
	my $pattern = "";

	foreach my $language (@{$languages}) {
		$pattern = $language_patterns{$language};
		$pattern_str = "$pattern|$pattern_str" if $pattern;
		#print "$language => $pattern_str\n";
	}
	return $pattern_str;
}

sub build_churn_complexity {
	my ($target_dir) = shift(@_);

	system("und uperl und.file.complexity.pl -db $output_dir/$target_dir/$target_dir.udb -v");
}

#print "error!!" unless check_prerequisite("git");
#print "error!!" unless check_prerequisite("a");

#my %file_stats = get_file_churn("git", "c++", "one month ago");
#print $file_stats{"builtin/rev-list.c"}{commits};
# my @langs = to_languages_array("java javascript");
# print get_language_pattern_str(@langs);
#my %file_stats = get_file_churn("a", "c++");

# my %test_file_stats = (
# 	'file.c' => {'commits' => 1},
# 	'Word.c' => {'commits' => 5},
# 	'Aora.c' => {'commits' => 5},
# 	'List.c' => {'commits' => 3},
# 	'last.c' => {'commits' => 3}
# );

# print "0) $ARGV[0]\n";
# print "1) $ARGV[1]\n";

#TODO: language 륌라미터�받을 �도�..
# 2번째 �라미터�language ��을 공백구분문자�로 받아�� 배열�만든
my $target_dir = $ARGV[0];
my @languages = to_languages_array(lc $ARGV[1]);

print "1/5) Check prerequisites (und in PATH and target is git repo.) ";
print "...Error!!\n" and exit unless check_prerequisite($target_dir);
print "... Done\n";
print "2/5) Retrieve last recently modified files ";
my %file_stats = get_file_churn($target_dir, @languages, $ARGV[2]);
print "... Done (total ", scalar keys %file_stats, " files)\n";
print "3/5) Export file churn to csv ($target_dir/file_churn.csv) ";
export_file_churn_to_csv($target_dir, %file_stats);
#print Dumper \%file_stats;
print "... Done\n";
print "4/5) Parse source files by using Understand \n";
build_und_database($target_dir, $ARGV[1]);
#print keys %file_stats;

print "5/5) Report result \n";
build_churn_complexity($target_dir);
#print Dumper \%file_stats;
print "... Done\n";
print "See result at '$output_dir/$target_dir' directory\n";
