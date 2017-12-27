#!/usr/bin/perl
#use 5.010;
use strict;
use warnings;
use autodie;
use Path::Class;
#chdir("$ARGV[0]");

my $scname = `basename $0`; chomp($scname);
my $sdir   = $ARGV[0];  # /path/to/SOUCRE
my $tdir   = $ARGV[1];  # /path/to/TARGET
sub usage 
{ 
   print "\nThis Script moves Video Files from Source to target Directory\n".
         " Recognized File Type : 3gp,mpg,mov,avi,mp4\n". "Usage:\n $scname ". 
         '</path/to/SOUCRE> ' . ' </path/to/TARGET>' ."\n";
   print "ENV VARS=>\n";
   system("env|grep PHOTO;env|grep NEX");
}
if (!defined $ARGV[0] || !-d $ARGV[0]) {$ARGV[0]="";&usage();die "\n SOURCE Path undefined ($ARGV[0])\n"}
if (!defined $ARGV[1] || !-d $ARGV[1]) {$ARGV[1]="";&usage();die "\n TARGET Path undefined ($ARGV[1])\n"}

for my $f ( dir("$ARGV[0]")->children ) {
  #print "$f->basename \n";
  next if $f->is_dir;
  if ( $f->basename =~ /3GP$|MPG$|MOV$|AVI$|MP4$/i ) {
    my $x=$f->basename;
    my $y=$x;
    $x =~ s/VID[_|\-]([0-9]{8})(.*)$/$1/i;
    my @chars=split('',$x);
    my $yyyy=join('',@chars[0..3]);
    my $mm=join('',@chars[4,5]);
    my $root=$yyyy."_".$mm;

    my ($nbasename,$extn)=split (/\./, $y);

    if (! -d "$tdir/$root" )
    {
      `mkdir "$tdir/$root"`;
      if( $? ne 0 )
      {
        print "\n Failed in mkdir $tdir/$root . Exiting \n";
        exit 1;
      }
  
    }
    if ( -f "$tdir/$root/$y" )
    {
       my $range = 88;
       my $rndd = int(rand($range)) +11;
       $y="$nbasename"."_"."$rndd.$extn";
    }
    print "cp -f $f $tdir/$root/$y\n\n\n";
    `cp -f $f $tdir/$root/$y`;
     if ( $? ne 0 )
     {
        print "\n failed in cp $f $tdir/$root/$y\n";
        exit 1;
     }

  }
}
