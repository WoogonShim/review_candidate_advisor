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
	my ($db, %file_churn_stats) = @_;

	my %file_churn_complexity_stats = ();
	foreach my $func ($db->ents("Function ~Unresolved ~Unknown ~Unused, Method ~Unresolved ~Unknown ~Unused")) {
		my $def      = $func->ref("definein");
		my $filename = $def->file->name();
		my $filepath = to_unix_path(abs2rel($def->file->longname(), $target_dir));

 		if (defined ($file_churn_stats{$filepath})) {
# 			print $func->name," from ",$filename,"\n";
			my $complexity = $func->metric("Cyclomatic");
			my $sloc       = $func->metric("CountLineCode");

			if( !defined( $complexity ) ) {
				next;
			}

			# initialize hash item values
			$file_churn_complexity_stats{$filepath}{sum_complexity} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{sum_complexity}));
			$file_churn_complexity_stats{$filepath}{funct_count} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{funct_count}));
			$file_churn_complexity_stats{$filepath}{max_complexity} = 0 if (!defined( $file_churn_complexity_stats{$filepath}{max_complexity}));
	 		$file_churn_complexity_stats{$filepath}{commits} = 
	 			$file_churn_stats{$filepath}{commits} if (!defined( $file_churn_complexity_stats{$filepath}{commits}));

			$file_churn_complexity_stats{$filepath}{sum_complexity} = $complexity + $file_churn_complexity_stats{$filepath}{sum_complexity};
			$file_churn_complexity_stats{$filepath}{funct_count} = $file_churn_complexity_stats{$filepath}{funct_count} + 1;

			my $max = $file_churn_complexity_stats{$filepath}{max_complexity};
			if($max <= $complexity) {
				$max            = $complexity;
				$file_churn_complexity_stats{$filepath}{max_complexity} = $max;
				$file_churn_complexity_stats{$filepath}{max_complexity_funct_name} = $func->name;
			}
			$file_churn_complexity_stats{$filepath}{functions}{$func->name}{complexity} = $complexity;
			$file_churn_complexity_stats{$filepath}{functions}{$func->name}{sloc}       = $sloc;
			$file_churn_complexity_stats{$filepath}{functions}{$func->name}{line_at}    = $def->line;
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

	my $file_churn_ccn_file_path = catfile($base_dir, "file_churn_complexity.csv");

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

	my $export_filepath = catfile($base_dir, "file_churn_complexity_functions.csv");

	open(EXPORT_CSV, '>:encoding(UTF-8)', $export_filepath)
		or die "Couldn't open 'file_churn_complexity_functions.csv': $1\n";

	print EXPORT_CSV "filename (line), function, complexity, sloc\n";
	# sort 1) commits desc 2) complexity desc, 3) filename asc with lowercase
	foreach (sort {($file_churn_complexity_stats{$b}{commits}    <=> $file_churn_complexity_stats{$a}{commits}) or
                   ($file_churn_complexity_stats{$b}{complexity} <=> $file_churn_complexity_stats{$a}{complexity}) or
		           (lc $a cmp lc $b)} keys %file_churn_complexity_stats ) {
		my $filename = $_;

		my %functions = %{$file_churn_complexity_stats{$_}{functions}};
		foreach (sort {($functions{$b}{complexity} <=> $functions{$a}{complexity}) or
		               (lc $a cmp lc $b)} keys %functions ) {
#			print "$filename ($functions{$_}{line_at}), $_, $functions{$_}{complexity}, $functions{$_}{sloc}\n";
        	print EXPORT_CSV "$filename ($functions{$_}{line_at}), $_, $functions{$_}{complexity}, $functions{$_}{sloc}\n";
        }
    }

	close EXPORT_CSV;
	#print Dumper \%file_churn_complexity_stats;
}

print "   (1/4) Read file commits (file_churn.csv) " if $verbose_flag;
my %file_churn_stats = read_file_churn_csv();
print "\t... Done\n" if $verbose_flag;
print "   (2/4) Build churn complexity (from " .basename($base_dir) .".udb) " if $verbose_flag;
my %file_churn_complexity_stats = build_churn_complexity($db, %file_churn_stats);
print "\t... Done\n" if $verbose_flag;
print "   (3/4) Export churn complexity file " if $verbose_flag;
export_file_churn_complexity_to_csv(%file_churn_complexity_stats);
print "\t\t... Done\n" if $verbose_flag;
print "\t ==> (file_churn_complexity.csv)\n" if $verbose_flag;
print "   (4/4) Export churn complexity function file " if $verbose_flag;
export_file_churn_complexity_functions_to_csv(%file_churn_complexity_stats);
print "\t... Done\n" if $verbose_flag;
print "\t ==> (file_churn_complexity_functions.csv)\n" if $verbose_flag;

$db->close();
print "Reporting churn complexity ... Done!\n" unless $verbose_flag;
