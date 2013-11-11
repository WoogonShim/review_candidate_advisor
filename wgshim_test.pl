#!/usr/bin/perl

use strict;
use warnings;
#use File::Which;
#use Text::CSV_XS;
use File::Spec::Functions qw( catfile path );
use Data::Dumper;

# ======================== USER CUSTOMIZING DATA ====================
my @language = ("c++", "java");

my %language_patterns = (
	"default" => 'h|hh|hpp|c|cc|cxx|cpp|java|js',
	#"c++" => 'h|hh|hpp|c|cc|cxx|cpp',
	"c++" => 'c',
	"java" => 'java',
	"javascript" => 'js',
	"android" => 'java|xml',
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
	my ($target_dir,$language) = @_;

	chdir $target_dir;
	print "und -quiet create -db $target_dir.udb -languages $language add -subdir on . settings -metrics AvgLineCode CountLineCodeExe AvgCyclomatic Cyclomatic MaxCyclomatic MaxNesting -metricsOutputFile metrics.csv";
	die;
	system("und -quiet create -db $target_dir.udb -languages $language add -subdir on . settings -metrics AvgLineCode CountLineCodeExe AvgCyclomatic Cyclomatic MaxCyclomatic MaxNesting -metricsOutputFile metrics.csv");
	chdir "..";
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
#     : get_file_complexity(filepath)
#   41) 20) 에서 얻은 파일 정보들에 대해... (모든 파일을 할 필요는 없음)
# 50) 저장된 데이터를 엑셀파일(혹은 csv 포맷으로)에 저장한다.
#     : store_file_churn_complexity
# 60) 저장된 정보를 바탕으로 file-churn-complexity chart 를 생성한다.
#     : draw_chart
#   61) perl 로 힘들다면 python 으로 차트를 생성하자.

sub get_file_churn($$;$) {
	my ($target_dir, $language, $export_flag) = @_;

	chdir $target_dir;

	my $COMMIT_FREQUENCY_COMMAND = 
	'git rev-list --since=\'one month ago\' --no-merges --objects --all | 
	grep -E \'*(' .$language_patterns{$language} .'$)\' | 
	awk \'"" != $2\' | sort -k2 | uniq -cf1 | sort -rn |
	while read frequency sha1 path 
	do 
		[ "blob" = "$(git cat-file -t $sha1)" ] && echo -e "$frequency\t$path"; 
	done';

	if ( ! open(GIT_REV_LIST,'-|', $COMMIT_FREQUENCY_COMMAND) ) {
	    die "Failed to process 'git rev-list': $!\n";
	}

	if ($export_flag) {
		open(FILE_CHURN, '>:encoding(UTF-8)', 'file_churn.csv') 
			or die "Couldn't open 'file_churn.csv': $1\n";
		print FILE_CHURN "filename, commits\n";
	}

	my %file_stats;
	my %function_complexities;
	while(my $churn_line = <GIT_REV_LIST>) {
		chomp $churn_line;
		if ($churn_line =~ m{^(\d+)\s+(.+)} ) {
			my $frequency= $1;
			my $filename = $2;

#			print ".";
			print FILE_CHURN "$filename, $frequency\n" if $export_flag;
#			print "$filename\t ($frequency commits)\n";
			$file_stats{$filename}{commits} = $frequency;
		} else {
			print "err> $churn_line\n";
		}
	}
	my $number_of_items = keys %file_stats;
	print "total ($number_of_items)\n";

	close GIT_REV_LIST;	
	close FILE_CHURN if $export_flag;
	return %file_stats;
}

sub export_csv_file_churn($) {
	my %file_stats = shift(@_);
	print 
}

sub get_language_list_str (\@) {
	my ($languages) = shift(@_);
	return join ", ", @{$languages};
}

sub get_language_pattern_str(\@) {
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

#print "error!!" unless check_prerequisite("git");
#print "error!!" unless check_prerequisite("a");

my %file_stats = get_file_churn("git", "c++");
print $file_stats{"builtin/rev-list.c"}{commits};

print get_language_pattern_str(@language);
build_und_database("git", "c++");
#print keys %file_stats;

print Dumper \%file_stats;
