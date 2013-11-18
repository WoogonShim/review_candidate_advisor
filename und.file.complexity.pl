#use lib '/cygdrive/c/Program Files/SciTools/bin/pc-win64/Perl/STI/Maintain';
use Understand;
# use Config;
use Data::Dumper;
use strict;
use warnings;
use File::Basename;
use File::Spec::Functions qw( catfile abs2rel );

# sub path_separator {
# 	if($Config{osname} =~ m{MSWin}) {
# 		return "\\";
# 	}
# 	return "/";
# }
#system("cls");

# print "0) $ARGV[0]\n";
# print "1) $ARGV[1]\n";
# print "2) " . Understand::CommandLine::db() ."\n";
our $output_dir = "churn-complexity-output";
our $verbose_flag = 0;
$verbose_flag = "-v" eq $ARGV[2] if (defined ($ARGV[2]));

my $db = Understand::CommandLine::db();

our $target_dir = basename($db->name(), ".udb");
my  $dblanguage = $db->language();

if ($dblanguage !~ /c|java/i) {
    closeDatabase($db);
    die "$dblanguage is currently unsupported";
}
#print $db."::\n";

sub read_file_churn_csv {
	my $file_churn_file_path = catfile("$output_dir/$target_dir", "file_churn.csv");
	open(FILE_CHURN, '<:encoding(UTF-8)', $file_churn_file_path)
		or die "Couldn't open 'file_churn.csv': $1\n";

	my %file_stats;
	while(my $churn_line = <FILE_CHURN>) {
		chomp $churn_line;
		if ($churn_line =~ m{^(.+),\s+(\d+)} ) {
			my $filepath = $1;
			my $frequency= $2;

			$file_stats{$filepath}{commits} = $frequency;
#			print $churn_line,"\n";
		}
	}
	close FILE_CHURN;
	return %file_stats;
}

sub to_unix_path {
	my $path = shift @_;
	$path =~ s{\\}{/}g;
	return $path;
}

# sub to_window_path {
# 	my $path = shift @_;
# 	$path =~ s{/}{\\}g;
# 	return $path;
# }

# sub get_file_complexity {
# 	my ($filepath, $db) = @_;

# 	my ($volume, $directories, $filename) = splitpath($filepath);
# 	my $_path = catfile($target_dir, $directories, $filename);

# 	my %file_complexity_stats;
# 	foreach my $file ($db->lookup($filename, "File")) {
# #		print $file->relname(),"\n";
# #		print $_path,"\n";
# 		if (index($_path, $file->relname()) != -1) {
# 		print "matched!!\n";
# 			my $count           = 0;
# 			my $sum             = 0;
# 			my $file_complexity = 0;
# 			my $max             = 0;
# 			my $max_funct_name  = "";
# 		print $file->relname(),"\n";
# 			foreach my $func ($file->ents("Function Method ~Unknown ~Unresolved ~Unused")) {
# 		print ">>>",$func->name(),",", $func->kindname,"\n";
# 				my $complexity = $func->metric("Cyclomatic");
# 				if( !defined( $complexity ) ) {
# 					next;
# 				}
# 				$file_complexity_stats{$func->name}{complexity} = $complexity;

# 				if($max <= $complexity) {
# 					$max            = $complexity;
# 					$max_funct_name = $func->name;
# 				}
# 				$sum += $complexity;
# 				$count++;
# 				print "   - ",$func->kindname(),"] ",$func->name(),"(", $complexity,")\n";
# 			}
# 			$file_complexity = $sum - $count + 1;
# 			print "total $count functions in '$filepath' (file ccn: $file_complexity)\n";
# #			print Dumper \%file_complexity_stats;

# 			return ($file_complexity, $count, $max, $max_funct_name, %file_complexity_stats);
# 		}
# 	}
# }

sub build_churn_complexity2 {
	my ($db, %file_churn_stats) = @_;

	my %file_churn_complexity_stats = ();
	foreach my $func ($db->ents("C Function ~Unresolved ~Unknown ~Unused, Java Method ~Unresolved ~Unknown ~Unused")) {
		my $def      = $func->ref("definein");
		my $filename = $def->file->name();
		my $filepath = to_unix_path(abs2rel($def->file->longname(), $target_dir));

 		if (defined ($file_churn_stats{$filepath})) {
# 			print $func->name," from ",$def->file->name(),"\n";
			my $complexity = $func->metric("Cyclomatic");
			if( !defined( $complexity ) ) {
				next;
			}

			$file_churn_complexity_stats{$filepath}{sum_complexity} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{sum_complexity}));
			$file_churn_complexity_stats{$filepath}{funct_count} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{funct_count}));
			$file_churn_complexity_stats{$filepath}{max_complexity} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{max_complexity}));

	 		$file_churn_complexity_stats{$filepath}{commits} = $file_churn_stats{$filepath}{commits};
			$file_churn_complexity_stats{$filepath}{sum_complexity} = $complexity + $file_churn_complexity_stats{$filepath}{sum_complexity};
			$file_churn_complexity_stats{$filepath}{funct_count} = $file_churn_complexity_stats{$filepath}{funct_count} + 1;

			my $max = $file_churn_complexity_stats{$filepath}{max_complexity};
			if($max <= $complexity) {
				$max            = $complexity;
				$file_churn_complexity_stats{$filepath}{max_complexity} = $max;
				$file_churn_complexity_stats{$filepath}{max_complexity_funct_name} = $func->name;
			}
			$file_churn_complexity_stats{$filepath}{functions}{$func->name}{complexity} = $complexity;
			$file_churn_complexity_stats{$filepath}{functions}{$func->name}{line}       = $def->line;
 		}
 	}

 	# hash 에서 sum_complexity 값이 없거나 0 인 녀석들을 삭제하고 반환한다.
 	foreach my $filepath (keys %file_churn_complexity_stats) {
 		if (defined ($file_churn_complexity_stats{$filepath}{sum_complexity})) {
 			$file_churn_complexity_stats{$filepath}{complexity} = 
 				$file_churn_complexity_stats{$filepath}{sum_complexity} - 
 				$file_churn_complexity_stats{$filepath}{funct_count} + 1;
#		print "$filepath (commit, ccn) = ($file_churn_complexity_stats{$_}{commits}, $file_churn_complexity_stats{$_}{complexity})\n";
 		}
 		else {
	 		delete $file_churn_complexity_stats{$filepath} 			
 		}
 	}
#	print Dumper \%file_churn_complexity_stats;
	return %file_churn_complexity_stats;
}

sub export_file_churn_complexity_to_csv {
	my (%file_churn_complexity_stats) = @_;

	my $file_churn_ccn_file_path = catfile("$output_dir/$target_dir", "file_churn_complexity.csv");
	open(FILE_CHURN_COMPLEXITY, '>:encoding(UTF-8)', $file_churn_ccn_file_path)
		or die "Couldn't open 'file_churn_complexity.csv': $1\n";

	print FILE_CHURN_COMPLEXITY "filename, commits, complexity, # of function, max function name, max complexity\n";
	# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
	foreach (sort {($file_churn_complexity_stats{$b}{commits}    <=> $file_churn_complexity_stats{$a}{commits}) or
                   ($file_churn_complexity_stats{$b}{complexity} <=> $file_churn_complexity_stats{$a}{complexity}) or
		           (lc $a cmp lc $b)} keys %file_churn_complexity_stats ) {
		print FILE_CHURN_COMPLEXITY "$_, " 
		      ."$file_churn_complexity_stats{$_}{commits}, "
		      ."$file_churn_complexity_stats{$_}{complexity}, "
		      ."$file_churn_complexity_stats{$_}{funct_count}, "
		      ."$file_churn_complexity_stats{$_}{max_complexity_funct_name}, "
		      ."$file_churn_complexity_stats{$_}{max_complexity}\n";
	}

	close FILE_CHURN_COMPLEXITY;
	#print Dumper \%file_churn_complexity_stats;
}

sub export_file_churn_complexity_functions_to_csv {
	my (%file_churn_complexity_stats) = @_;

	my $export_filepath = catfile("$output_dir/$target_dir", "file_churn_complexity_functions.csv");
	open(EXPORT_CSV, '>:encoding(UTF-8)', $export_filepath)
		or die "Couldn't open 'file_churn_complexity_functions.csv': $1\n";

	print EXPORT_CSV "filename (line), function, complexity\n";
	# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
	foreach (sort {($file_churn_complexity_stats{$b}{commits}    <=> $file_churn_complexity_stats{$a}{commits}) or
                   ($file_churn_complexity_stats{$b}{complexity} <=> $file_churn_complexity_stats{$a}{complexity}) or
		           (lc $a cmp lc $b)} keys %file_churn_complexity_stats ) {
		my $filename = $_;

		my %functions = %{$file_churn_complexity_stats{$_}{functions}};
		foreach (sort {($functions{$b}{complexity} <=> $functions{$a}{complexity}) or
		               (lc $a cmp lc $b)} keys %functions ) {
#			print "$filename ($functions{$_}{line}), $_, $functions{$_}{complexity}\n";
        	print EXPORT_CSV "$filename ($functions{$_}{line}), $_, $functions{$_}{complexity}\n";
        }
    }

	close EXPORT_CSV;
	#print Dumper \%file_churn_complexity_stats;
}

sub build_churn_complexity {
	my ($db, %file_churn_stats) = @_;

	my %file_churn_complexity_stats;
	# git rev-list 에서는 찾아졌지만 udb 에는 없는 파일이 있다!!!
	foreach (sort {($file_churn_stats{$b}{commits} <=> $file_churn_stats{$a}{commits}) or
		           (lc $a cmp lc $b)} keys %file_churn_stats ) {
	#	print "'$_': $file_churn_stats{$_}{commits} commits\n";
		my ($complexity, $count, $max, $max_funct_name, %file_complexity_stats) = get_file_complexity($_, $db);
		next unless %file_complexity_stats;

		$file_churn_complexity_stats{$_}{commits}   = $file_churn_stats{$_}{commits};
		$file_churn_complexity_stats{$_}{complexity}= $complexity;
		$file_churn_complexity_stats{$_}{funct_count}  = $count;
		$file_churn_complexity_stats{$_}{max_complexity}= $max;
		$file_churn_complexity_stats{$_}{max_complexity_funct_name} = $max_funct_name;
		$file_churn_complexity_stats{$_}{functions} = \%file_complexity_stats;
#		print "$_ (commit, ccn) = ($file_churn_complexity_stats{$_}{commits}, $file_churn_complexity_stats{$_}{complexity})\n";
	}
#	print Dumper \%file_churn_complexity_stats;
	return %file_churn_complexity_stats;
}

print "   (1/4) Read file commits ($target_dir/file_churn.csv) " if $verbose_flag;
my %file_churn_stats = read_file_churn_csv();
print "\t... Done\n" if $verbose_flag;
print "   (2/4) Build churn complexity (from $target_dir.udb) " if $verbose_flag;
my %file_churn_complexity_stats = build_churn_complexity2($db, %file_churn_stats);
print "\t... Done\n" if $verbose_flag;
# my %file_churn_complexity_stats = build_churn_complexity($db, %file_churn_stats);
print "   (3/4) Export churn complexity file " if $verbose_flag;
export_file_churn_complexity_to_csv(%file_churn_complexity_stats);
print "\t\t... Done\n" if $verbose_flag;
print "\t ==> ($target_dir/file_churn_complexity.csv)\n" if $verbose_flag;
print "   (4/4) Export churn complexity function file " if $verbose_flag;
export_file_churn_complexity_functions_to_csv(%file_churn_complexity_stats);
print "\t... Done\n" if $verbose_flag;
print "\t ==> ($target_dir/file_churn_complexity_functions.csv)\n" if $verbose_flag;
#get_file_complexity("src/main/java/org/junit/runners/ParentRunner.java", $db);


# my $file_churn_ccn_file_path = catfile($target_dir, "file_churn_complexity.csv");

# open(FILE_CHURN_COMPLEXITY, '>:encoding(UTF-8)', $file_churn_complexity_file_path)
# 	or die "Couldn't open 'file_churn_complexity.csv': $1\n";
# print FILE_CHURN_COMPLEXITY "filename, commits, complexity\n";

# my %file_churn_complexity_stats;
# # git rev-list 에서는 찾아졌지만 udb 에는 없는 파일이 있다!!!
# foreach (sort {($file_churn_stats{$b}{commits} <=> $file_churn_stats{$a}{commits}) or
# 	           (lc $a cmp lc $b)} keys %file_churn_stats ) {
# #	print "'$_': $file_churn_stats{$_}{commits} commits\n";
# 	my ($sum, %file_complexity_stats) = get_file_complexity($target_dir, $_, $db);
# 	next unless %file_complexity_stats;

# 	# TODO: 실존하지 않는 데이터를 해시에서 제거할 것
# 	# TODO: file, function, ccn 에 대한 정보를 csv 파일로 만들 것
# 	$file_churn_complexity_stats{$_}{commits}   = $file_churn_stats{$_}{commits};
# 	$file_churn_complexity_stats{$_}{complexity}       = $sum;
# 	$file_churn_complexity_stats{$_}{functions} = $file_complexity_stats{$_};
# 	print "$_ (commit, ccn) = ($file_churn_complexity_stats{$_}{commits}, $file_churn_complexity_stats{$_}{complexity})\n";
# 	print FILE_CHURN_COMPLEXITY "$_, $file_churn_complexity_stats{$_}{commits}, $file_churn_complexity_stats{$_}{complexity}\n";
# 	#print Dumper \%file_complexity_stats;
# #	print Dumper \%file_churn_complexity_stats;
# }
# close FILE_CHURN_COMPLEXITY;

$db->close();
print "Reporting churn complexity ... Done!\n" unless $verbose_flag;
