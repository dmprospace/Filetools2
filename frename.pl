#!/usr/bin/perl

use MIME::Lite;
use File::Basename;
use Time::Local; 
use POSIX qw(strftime);
use File::Basename; 
use Time::Local; 
use File::stat;
#use File::Cmp;


my $dirname=$ARGV[0];
my $scrname=`basename $0`;
chomp($scrname);

if (!(defined $dirname && -d $dirname))
{
 print "\nUsage: " . $scrname  . ' <PATH> ' ."\n\n";
 exit 1;
}


opendir my $dirhandle, "$dirname" or die "Cannot open directory: $!";

## echo for i in `ls -lart |tr -s ' '|cut -d ' ' -f 9-200|egrep -v '^\.'|tr ' ' '_'`; do j="`echo $i|tr '_' ' '`"; mv "$j" $i; done

my @files = glob( "$dirname/" . '*.*' );

foreach my $filename (@files)
{
    my $shortfilename =  basename($filename);
    my $newfilename   =  $shortfilename;
    $newfilename      =~ s/^[\s]+|[\s]+$//g;
    $newfilename      =~ s/[\s]/_/g;
    $newfilename      =~ s/\-/_/g;
    $newfilename      =~ s/\(|\)/_/g;
    $newfilename      =~ s/\[|\]/_/g;
    $newfilename      =~ s/[_]+/_/g;
    print "\n $dirname/$newfilename";
    if ( "$filename" ne "$dirname/$newfilename" )
    {
        `mv "$filename" "$dirname/$newfilename"`;
    }
}
print "\n";
closedir $dirhandle;
