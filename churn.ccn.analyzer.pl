#!/usr/bin/perl

use strict;
use warnings;
use File::Path qw( make_path );
use File::Basename qw( dirname basename );
use File::Spec::Functions qw( catfile path curdir abs2rel rel2abs );
use Data::Dumper;
use Cwd qw(abs_path cwd );

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
use constant PATHEXT => path;
#use constant PATHEXT => split /;/, $ENV{PATHEXT};

sub which {
	my $name = shift;

	grep { -e } map { my $file = $_; 
		map { catfile $_, $file } PATH
		} 
		map { $name . lc $_ } (q{}, PATHEXT);
}

our $target_dir  = abs_path($ARGV[0]);
our $working_dir = cwd();

our $dirnames    = dirname(rel2abs($target_dir, $working_dir));
our $target_name = basename($target_dir);
our $result_dir  = "$output_dir$dirnames/$target_name";

sub check_prerequisite($) {
	my $target_dir = shift(@_);

	if (! -d $target_dir) {
		print "\n\tTarget directory('$target_dir') is not exists!\n";
		return "";
	}

	# print "\n";
	# print "\t RESULT_DIR : $result_dir\n";
	# print "\t TARGET_DIR : $target_dir\n";

	if (! -d $result_dir) {
		make_path $result_dir;
	}

	my $und_exists = which('und');
	if (!$und_exists) {
		print "You should install Understand and add path on your PATH\n";
		return "";
	} 

	my $_git_folder = catfile($target_dir, ".git");
	if (! -d $_git_folder) {
		print "'$target_dir' is not a git repository!\n";
		return "";
	}
	return 1;
}

sub build_und_database($$) {
	my ($target_dir,$languages) = @_;

	my $target_und_db_file = catfile($result_dir, "$target_name.udb");

	my $BUILD_DATABASE_COMMAND = "und -quiet "
	."create -db $target_und_db_file -languages $languages "
	."-JavaVersion java6 "
	."add "
		."-exclude .git "
		."-subdir on $target_dir "
	."settings "
		 ."-metrics "
		 	."CountLineCode "
		 	."Cyclomatic "
		 	."MaxCyclomatic "
		 	."MaxNesting "
		 ."-metricsOutputFile "
		 .catfile($result_dir, "metrics.csv");
#	print "$BUILD_DATABASE_COMMAND\n";	
	system($BUILD_DATABASE_COMMAND);

	my $ANALYZE_DATABASE_COMMAND = 
		"und -quite analyze -db $target_und_db_file";

	if ( ! open(ANALYZE_DATABASE,'-|', $ANALYZE_DATABASE_COMMAND) ) {
	    die "Failed to process 'und analyze -db $target_und_db_file': $!\n";
	}
	while(my $db_analysis = <ANALYZE_DATABASE>) {
		chomp $db_analysis;
		if ($db_analysis =~ m{Errors:(\d+)\s+Warnings:(\d+)} ) {
			print "... $db_analysis\n";
		}
	}
}

# 10) 환경 확인
#     : check_prerequisite
#   11) und 실행파일이 PATH 상에 존재하는지 확인한다.
#   12) 현재 폴더가 git repository 인지 확인한다. (.git 폴더 유무 검사)
# 20) 위치에 und 데이터베이스를 생성한다. (.udb 파일)
#     : build_und_database
#   21) und 데이터베이스 생성
#   22) 셋팅정보 설정 (인코딩, 언어, 메트릭, 등 설정)
#   23) und 데이터베이스에 파일 추가 & 분석
# 30) git 에서 최근 한 달 간의 파일 당 커밋 빈도를 측정한다.
#     : get_file_churn
#   31) 파일당 커밋 빈도를 파일에 저장한다. (중간 산출물)
# 40) udb 에서 파일 당 함수의 복잡도와 LOC, 파일의 복잡도를 측정한다.
#     : build_churn_complexity(filepath)
#   41) 20) 에서 얻은 파일 정보들에 대해... (모든 파일을 할 필요는 없음)
# 50) 저장된 데이터를 엑셀파일(혹은 csv 포맷으로)에 저장한다.
#     : export_file_churn_to_csv
# 60) 저장된 정보를 바탕으로 file-churn-complexity chart 를 생성한다.
#     : draw_chart
#   61) perl 로 힘들다면 python 으로 차트를 생성하자.

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
		if ($churn_line =~ m{(\d+)\s+(.+)} ) {
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
	chdir $working_dir;
	return %file_stats;
}

sub export_file_churn_to_csv {
	my ($target_dir, $file_stats) = @_;

	my $file_churn_file_path = catfile($result_dir, "file_churn.csv");

	open(FILE_COUNT, ">", catfile($result_dir, "file-count"))
		or die "Couldn't open 'file-count': $!\n";
	print FILE_COUNT scalar keys %{$file_stats};
	close FILE_COUNT;

	open(FILE_CHURN, '>:encoding(UTF-8)', $file_churn_file_path)
		or die "Couldn't open 'file_churn.csv': $!\n";

	print FILE_CHURN "filename, commits\n";
	# sort 1) commits desc 2) filename asc with lowercase
	foreach (sort {($file_stats->{$b}{commits} <=> $file_stats->{$a}{commits}) or
		           (lc $a cmp lc $b)} keys %{$file_stats} ) {
#		print "$_ : $file_stats->{$_}{commits}\n";
		print FILE_CHURN "$_, $file_stats->{$_}{commits}\n";
	}
	close FILE_CHURN;
	#print Dumper \%{$file_stats};
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

	my $target_und_db_file = catfile($result_dir, "$target_name.udb");
	system("und uperl und.file.complexity.pl $target_dir -db $target_und_db_file -v");
}

# print "0) $ARGV[0]\n";
# print "1) $ARGV[1]\n";

#TODO: Usage 출력 및 파라미터 파싱 필요
my @languages = to_languages_array(lc $ARGV[1]);

my $HIGHLIGHT="\e[01;34m";
my $NORMAL="\e[00m";

print $HIGHLIGHT,"================================================================================", "$NORMAL\n";
print $HIGHLIGHT," Generate churn (commit frequency) vs complexity ", "$NORMAL\n";
print "   > from '$target_dir'\n";
print $HIGHLIGHT,"================================================================================", "$NORMAL\n";
print $HIGHLIGHT,"1/5) Check prerequisites ('und' in PATH and target is git repo.)$NORMAL ";
print "...Error!!\n" and exit unless check_prerequisite($target_dir);
print "... Done\n";
print $HIGHLIGHT,"2/5) Retrieve last recently modified files$NORMAL ";
my %file_stats = get_file_churn($target_dir, @languages, $ARGV[2]);
print "... Done (total ", scalar keys %file_stats, " files)\n";
my $file_churn_file_path = catfile(basename($target_dir), "file_churn.csv");
print $HIGHLIGHT,"3/5) Export file churn to csv ($file_churn_file_path)$NORMAL ";
export_file_churn_to_csv($target_dir, \%file_stats);
#print Dumper \%file_stats;
print "... Done\n";
print $HIGHLIGHT,"4/5) Parse source files by using Understand$NORMAL \n";
build_und_database($target_dir, $ARGV[1]);
#print keys %file_stats;

print $HIGHLIGHT,"5/5) Report result$NORMAL \n";
build_churn_complexity($target_dir);
#print Dumper \%file_stats;
print "... Done\n";
print "See result at $HIGHLIGHT'$result_dir'$NORMAL directory\n";
