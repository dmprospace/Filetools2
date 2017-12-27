#!/usr/bin/perl


my $fin=$ARGV[0];


if ( -f $fin )
{
	open FH, "<$fin" || die 'Yuck! File didnt open';
}
else
{
	print "\n Nope on File\n";
	exit;
}

my @lines=<FH>;

my $mac=''; 
$mac .= 'VERSION BUILD=8920312 RECORDER=FX' . "\n";
$mac .= 'TAB T=1' . "\n";
print "$mac\n";

foreach my $l(@lines)
{
my $mac=''; 
$/="\r\n";
chomp($l);
$/="\n";
@rec=split(/\t/,$l);
my $fn="$rec[0]";
my $ln="$rec[1]";
my $em="$rec[2]";
my $zc="$rec[3]";chomp($zc); 


$mac .= 'URL GOTO=https://petitions.whitehouse.gov//petition/allow-filing-i-765-ead-and-i-131-ap-upon-i-140-approval-4' . "\n";
$mac .= 'EVENT TYPE=CLICK SELECTOR="#edit-first-name" BUTTON=0'. "\n";
$mac .= 'EVENTS TYPE=KEYPRESS SELECTOR="#edit-first-name" CHARS="' . "$fn" .'"'. "\n";
$mac .= 'EVENT TYPE=KEYPRESS SELECTOR="#edit-first-name" KEY=9'. "\n";
$mac .= 'EVENTS TYPE=KEYPRESS SELECTOR="#edit-last-name" CHARS="' . "$ln" .'"' . "\n";
$mac .= 'EVENT TYPE=KEYPRESS SELECTOR="#edit-last-name" KEY=9'. "\n";
$mac .= 'EVENTS TYPE=KEYPRESS SELECTOR="#edit-email" CHARS="' . "$em" .'"'. "\n";
$mac .= 'EVENTS TYPE=KEYPRESS SELECTOR="#edit-zip-code" CHARS="' . "$zc" . '"'. "\n";
$mac .= 'EVENT TYPE=CLICK SELECTOR="#edit-submit" BUTTON=0'. "\n";
$mac .= 'WAIT SECONDS=6'. "\n". "\n";

print "$mac\n";

}

