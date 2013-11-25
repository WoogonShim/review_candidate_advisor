#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw( dirname basename );
use File::Spec::Functions qw( catfile path curdir abs2rel rel2abs );
use Cwd qw( abs_path cwd );
use Data::Dumper;

our $working_dir = cwd();

my $git_repo_list_filepath = catfile($working_dir, "git-repo-list");

my $target_path = '.';
$target_path = $ARGV[0] if defined($ARGV[0]);
our @git_repo_list = ();

sub scan_git_repo_dir {
    my ($dir) = @_;

    # 절대경로로 변경 + 
    $dir = abs_path($dir);

	if (! -d $dir) {
		print "\n\tDirectory('$dir') is not exists!\n";
		return;
	}

    # git 폴더라면 배열에 저장하고 빠져나간다.
	my $_git_folder = catfile($dir, ".git");
	if ( -d $_git_folder ) {
		push @git_repo_list, $dir;
#	    print "git ] $_ (", scalar @git_repo_list,")\n";
		return;
	}

    opendir DIR, $dir || warn "Cannot open directory $dir: $!";
    my @files = readdir DIR ;
    closedir DIR;

    @files = grep {$_ !~ /^(\.|\.\.)$/} @files;

    # my @simpleFiles = grep -f, (map {"$dir/$_"} @files);
    my @directories = grep -d, (map {"$dir/$_"} @files);
    foreach (@directories) { 
    	scan_git_repo_dir($_); 
#	    print "each ] $_ (", scalar @git_repo_list,")\n";
    }
    return;
}

sub git_pull {
	my ($git_directory) = shift @_;

	chdir $_;	
	system("git pull 2>/dev/null");
}

sub write_repo_list {
	my (@git_repo_list) = @_;

	open(GIT_REPO_LIST_FILE, ">", $git_repo_list_filepath)
		or die "Couldn't open 'git-repo-list': $!\n";

	my $total = scalar @git_repo_list;
	my $count = 0;
	foreach (sort {$a cmp $b} @git_repo_list) {
		$count++;
		print "[$count/$total]> $_\n";
		print GIT_REPO_LIST_FILE $_,"\n";
		git_pull($_);
	}
	close GIT_REPO_LIST_FILE;
}

my $HIGHLIGHT="\e[01;34m";
my $NORMAL="\e[00m";

print $HIGHLIGHT,"Scanning $target_path", "$NORMAL\n";
scan_git_repo_dir($target_path);
# print Dumper \@git_repo_list;
write_repo_list(@git_repo_list);
print $HIGHLIGHT,"Scanning completed (total ", scalar @git_repo_list, " repos)", "$NORMAL\n";
