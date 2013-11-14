#use lib '/cygdrive/c/Program Files/SciTools/bin/pc-win64/Perl/STI/Maintain';
use Understand;
use strict;
use warnings;

#system("cls");

my $ver = Understand::version();
print "Understand Ver.: ", $ver, "\n";

print "0) $ARGV[0]\n";
print "1) $ARGV[1]\n";
print "2) " . Understand::CommandLine::db() ."\n";

#print $ARGV[2]."\n";
#die;
#my $db_name = $ARGV[2];
#print $db_name ."\n";

#my ($db, $status) = Understand::open($db_name);
#my ($db, $status) = Understand::open("a.udb");
#die "Error status: ",$status,"\n" if $status;

my $db = Understand::CommandLine::db();
#print $db."::\n";

foreach my $file ($db->ents("File")) {
	# print the long name (ie, show directory names)
	print $file->longname(),"\n";
}

