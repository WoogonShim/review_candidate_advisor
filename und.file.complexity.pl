#use lib '/cygdrive/c/Program Files/SciTools/bin/pc-win64/Perl/STI/Maintain';
use Understand;
use Data::Dumper;
use strict;
use warnings;
use File::Basename;
use File::Spec::Functions qw( catfile abs2rel rel2abs curdir );

# print "0) $ARGV[0]\n";
# print "1) $ARGV[1]\n";
# print "2) $ARGV[2]\n";
# print "3) " . Understand::CommandLine::db() ."\n";
# print "4) $ARGV[3]\n";
our $verbose_flag = 0;
$verbose_flag = "-v" eq lc $ARGV[3] if (defined ($ARGV[3]));

my $db = Understand::CommandLine::db();

our $base_dir   = dirname($db->name());
our $target_dir = rel2abs($ARGV[2]);

my  $dblanguage = $db->language();

if ($dblanguage !~ /c|java|web/i) {
    $db->close();
    die "$dblanguage is currently unsupported";
}

# Define global scope for referencing from each Comparator
my %file_churn_complexity_stats = ();

sub read_file_churn_csv {
	my $file_churn_file_path = catfile($base_dir, "file_churn.csv");

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

sub get_extension {
	my $filename = shift @_;
	my ($ext) = $filename =~ /(\.[^.]+)$/;
	return $ext;
}

sub build_churn_complexity {
	my ($db, $file_churn_stats) = @_;

	my %stats = ();
	foreach my $func ($db->ents("Function ~Unresolved ~Unknown ~Unused, Method ~Unresolved ~Unknown ~Unused")) {
		my $def      = $func->ref("definein");
		my $filename = $def->file->name();
		my $filepath = to_unix_path(abs2rel($def->file->longname(), $target_dir));

 		if (defined ($file_churn_stats->{$filepath})) {
# 			print $func->name," from ",$filename,"\n";
			my $complexity = $func->metric("Cyclomatic");
			my $sloc       = $func->metric("CountLineCode");

			if( !defined( $complexity ) ) {
				next;
			}

			# initialize hash item values
			$stats{$filepath}{sum_complexity} = 0 if (!defined( $stats{$filepath}{sum_complexity}));
			$stats{$filepath}{funct_count} = 0 if (!defined( $stats{$filepath}{funct_count}));
			$stats{$filepath}{avg_complexity} = 0 if (!defined( $stats{$filepath}{avg_complexity}));
			$stats{$filepath}{max_complexity} = 0 if (!defined( $stats{$filepath}{max_complexity}));
	 		$stats{$filepath}{commits} =
	 			$file_churn_stats->{$filepath}{commits} if (!defined( $stats{$filepath}{commits}));

			$stats{$filepath}{sum_complexity} = $complexity + $stats{$filepath}{sum_complexity};
			$stats{$filepath}{funct_count} = $stats{$filepath}{funct_count} + 1;

			my $max = $stats{$filepath}{max_complexity};
			if($max <= $complexity) {
				$max            = $complexity;
				$stats{$filepath}{max_complexity} = $max;
				$stats{$filepath}{max_complexity_funct_name} = $func->name;
			}
			$stats{$filepath}{functions}{$func->name}{complexity} = $complexity;
			$stats{$filepath}{functions}{$func->name}{sloc}       = $sloc;
			$stats{$filepath}{functions}{$func->name}{line_at}    = $def->line;
 		}
 	}

 	# hash 에서 sum_complexity 값이 없거나 0 인 녀석들을 삭제하고 반환한다.
 	foreach my $filepath (keys %stats) {
 		if (defined ($stats{$filepath}{sum_complexity})) {
 			$stats{$filepath}{file_complexity} =
 				$stats{$filepath}{sum_complexity} -
 				$stats{$filepath}{funct_count} + 1;
 			$stats{$filepath}{avg_complexity} =
 				$stats{$filepath}{sum_complexity} /
 				$stats{$filepath}{funct_count};
#		print "$filepath (commit, ccn) = ($stats{$_}{commits}, $stats{$_}{complexity})\n";
 		}
 		else {
 			delete $stats{$filepath};
 		}
 	}
#	print Dumper \%stats;
	return %stats;
}

# Comparator
# sort 1) commits desc 2) max complexity desc, 3) function name asc with lowercase, 4) filename asc with lowercase
# sub by_max_complexity {
# 	( $file_churn_complexity_stats{$b}{'commits'} <=> $file_churn_complexity_stats{$a}{'commits'} )
# 		or
# 	( $file_churn_complexity_stats{$b}{'max_complexity'} <=> $file_churn_complexity_stats{$a}{'max_complexity'} )
# 		or
# 	( lc $file_churn_complexity_stats{$a}{'max_complexity_funct_name'} cmp lc $file_churn_complexity_stats{$b}{'max_complexity_funct_name'} ) 
# 		or
# 	( lc $a cmp lc $b )
# }

# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
# sub by_file_complexity {
# 	( $file_churn_complexity_stats{$b}{'commits'} <=> $file_churn_complexity_stats{$a}{'commits'} )
# 		or
# 	( $file_churn_complexity_stats{$b}{'file_complexity'} <=> $file_churn_complexity_stats{$a}{'file_complexity'} )
# 		or
# 	( lc $a cmp lc $b )
# }

sub export_csv_sorted_by_file_complexity {
	my ($file_churn_complexity_stats) = @_;

	my $file_churn_ccn_file_path = catfile($base_dir, "file_churn_complexity.csv");

	open(FILE_CHURN_COMPLEXITY, '>:encoding(UTF-8)', $file_churn_ccn_file_path)
		or die "Couldn't open 'file_churn_complexity.csv': $1\n";

	print FILE_CHURN_COMPLEXITY "filename, commits, file complexity, # of function, avg complexity, max function name, max complexity\n";
	# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
	foreach (sort {
	( $file_churn_complexity_stats->{$b}{'commits'} <=> $file_churn_complexity_stats->{$a}{'commits'} )
		or
	( $file_churn_complexity_stats->{$b}{'file_complexity'} <=> $file_churn_complexity_stats->{$a}{'file_complexity'} )
		or
	( lc $a cmp lc $b )
} keys %{$file_churn_complexity_stats} ) {
		print FILE_CHURN_COMPLEXITY "$_, "
		      ,"$file_churn_complexity_stats->{$_}{'commits'}, "
		      ,"$file_churn_complexity_stats->{$_}{'file_complexity'}, "
		      ,"$file_churn_complexity_stats->{$_}{'funct_count'}, "
		      ,"$file_churn_complexity_stats->{$_}{'avg_complexity'}, "
		      ,"$file_churn_complexity_stats->{$_}{'max_complexity_funct_name'}, "
		      ,"$file_churn_complexity_stats->{$_}{'max_complexity'} \n";
	}

	close FILE_CHURN_COMPLEXITY;
	#print Dumper \%{$file_churn_complexity_stats};
}

sub export_csv_sorted_by_max_function_complexity {
	my ($file_churn_complexity_stats) = @_;

	my $file_churn_ccn_max_file_path = catfile($base_dir, "file_churn_complexity_max.csv");

	open(FILE_CHURN_COMPLEXITY_MAX, '>:encoding(UTF-8)', $file_churn_ccn_max_file_path)
		or die "Couldn't open 'file_churn_complexity_max.csv': $1\n";

	print FILE_CHURN_COMPLEXITY_MAX "filename, max function name, commits, max complexity, file complexity, # of function, avg complexity\n";
	# sort 1) commits desc 2) max complexity desc, 3) filename asc with lowercase
	foreach (sort {
	( $file_churn_complexity_stats->{$b}{'commits'} <=> $file_churn_complexity_stats->{$a}{'commits'} )
		or
	( $file_churn_complexity_stats->{$b}{'max_complexity'} <=> $file_churn_complexity_stats->{$a}{'max_complexity'} )
		or
	( lc $file_churn_complexity_stats->{$a}{'max_complexity_funct_name'} cmp lc $file_churn_complexity_stats->{$b}{'max_complexity_funct_name'} ) 
		or
	( lc $a cmp lc $b )
} keys %{$file_churn_complexity_stats} ) {
		print FILE_CHURN_COMPLEXITY_MAX "$_, "
		      ."$file_churn_complexity_stats->{$_}{'max_complexity_funct_name'}, "
		      ."$file_churn_complexity_stats->{$_}{'commits'}, "
		      ."$file_churn_complexity_stats->{$_}{'max_complexity'}, "
		      ."$file_churn_complexity_stats->{$_}{'file_complexity'}, "
		      ."$file_churn_complexity_stats->{$_}{'funct_count'}, "
		      ."$file_churn_complexity_stats->{$_}{'avg_complexity'}"
		      ."\n";
	}

	close FILE_CHURN_COMPLEXITY_MAX;
	#print Dumper \%{$file_churn_complexity_stats};
}

sub export_file_churn_complexity_functions_to_csv {
	my ($file_churn_complexity_stats) = @_;

	my $export_filepath = catfile($base_dir, "file_churn_complexity_functions.csv");

	open(EXPORT_CSV, '>:encoding(UTF-8)', $export_filepath)
		or die "Couldn't open 'file_churn_complexity_functions.csv': $1\n";

	print EXPORT_CSV "filename (line), function, complexity, sloc\n";
	# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
	foreach (sort {
	( $file_churn_complexity_stats->{$b}{'commits'} <=> $file_churn_complexity_stats->{$a}{'commits'} )
		or
	( $file_churn_complexity_stats->{$b}{'file_complexity'} <=> $file_churn_complexity_stats->{$a}{'file_complexity'} )
		or
	( lc $a cmp lc $b )
} keys %{$file_churn_complexity_stats} ) {
		my $filename = $_;

		my %functions = %{$file_churn_complexity_stats->{$_}{functions}};
		foreach (sort {($functions{$b}{complexity} <=> $functions{$a}{complexity}) or
		               (lc $a cmp lc $b)} keys %functions ) {
#			print "$filename ($functions{$_}{line_at}), $_, $functions{$_}{complexity}, $functions{$_}{sloc}\n";
        	print EXPORT_CSV "$filename ($functions{$_}{line_at}), $_, $functions{$_}{complexity}, $functions{$_}{sloc}\n";
        }
    }

	close EXPORT_CSV;
	#print Dumper \%{$file_churn_complexity_stats};
}

my $HIGHLIGHT="\e[01;34m";
my $NORMAL="\e[00m";

print $HIGHLIGHT,"   =========================================================", "$NORMAL\n";
print $HIGHLIGHT,"    Calculate cyclomatic complexity by using Understand ", "$NORMAL\n";
print $HIGHLIGHT,"   =========================================================", "$NORMAL\n";
print "   (1/4) Read file commits (file_churn.csv) " if $verbose_flag;
my %file_churn_stats = read_file_churn_csv();
print "\t... Done\n" if $verbose_flag;
print "   (2/4) Build churn complexity (from " .basename($base_dir) .".udb) " if $verbose_flag;
%file_churn_complexity_stats = build_churn_complexity($db, \%file_churn_stats);
print "\t... Done\n" if $verbose_flag;
print "   (3/4) Export churn complexity file " if $verbose_flag;
export_csv_sorted_by_file_complexity(\%file_churn_complexity_stats);
export_csv_sorted_by_max_function_complexity(\%file_churn_complexity_stats);
print "\t\t... Done\n" if $verbose_flag;
print "\t ==> (file_churn_complexity.csv)\n" if $verbose_flag;
print "   (4/4) Export churn complexity function file " if $verbose_flag;
export_file_churn_complexity_functions_to_csv(\%file_churn_complexity_stats);
print "\t... Done\n" if $verbose_flag;
print "\t ==> (file_churn_complexity_functions.csv)\n" if $verbose_flag;

$db->close();
print $HIGHLIGHT,"   Reporting churn complexity ... Done!$NORMAL\n"
