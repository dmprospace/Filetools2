#!/usr/bin/perl

my $line=<STDIN>;
chomp($line);
while ($line ne ''){
	my @fields=split(/,/,$line);
	print ("$fields[3],$fields[0],$fields[2]\n");
	$line=<STDIN>;
	chomp($line);
}

my $x = 0  | 2 | 4;
print "\nx=$x:\n";

my $y = 0 || 2 ;#|| 4;
print "\ny=$y:\n";

my ($a,@b,$c) = qw( 1 2 3 4 5 );
print "\na=$a:b=@b:c=$c\n";

my $a = (4,2,3);
print "\na=$a\n";

my $num="801-696-8658";

@ar= ($num =~/([2-9][0-9][0-9]|)[-]{0,1}([0-9]{3})-([0-9]{4})/);
print "\nacode=$ar[0]:local=$ar[1]:number=$ar[2]\n";

my $dir='/usr/bin/perl';

$dir=~ s/(.+)\/.*/$1/;

print "\n\np:$dir\n";
