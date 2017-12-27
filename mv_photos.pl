#!/usr/bin/perl
#use 5.010;
use strict;
use warnings;
use autodie;
use Digest::MD5 'md5_hex';
use Image::ExifTool 'ImageInfo';
use Path::Class;
my $extn='';

my $scname=`basename $0`; chomp($scname);
my $src	  =$ARGV[0]; # /path/to/SOUCRE
my $tgt   =$ARGV[1]; # /path/to/TARGET
my $ed    =$ARGV[2]; # Only look for Empty Date Files [which means when ed=1; only Empty Date Files are processed, ed=0 is preferred ]
my $norma =$ARGV[3]; # Do Normalization First Before moving Pics

sub usage
{
   print "\nThis Script standardizes Names Picture Files & moves from Source to target Directory w/ standard name\n".
         " Recognized File Type : jpg,jpeg,png\n". "Usage:\n $scname ".
         '</path/to/SOUCRE>  </path/to/TARGET> <empty_detect_only> <normalize_also>' ."\n".
         ""."\n"  ;
   print "ENV VARS=>\n";
   system("env|grep PHOTO;env|grep NEX");
}
if (scalar @ARGV >0)
{
	if ( !defined $ARGV[0] || !-d $ARGV[0]) {$ed=0; $norma=0;&usage();die "\n Bad SOURCE Path ($ARGV[0])\n"}
	if ( !defined $ARGV[1] || !-d $ARGV[1]) {$ed=0; $norma=0;&usage();die "\n Bad TARGET Path ($ARGV[1])\n"}
}
else
{
	print "\nError: No Parameters Passed!\n";
	$ed=0; $norma=0;
	&usage();
	exit 1;
}

if ($norma > 0)
{
	print ("\nTrying Normalization\n");
	system("~/bin/norm.sh $src 2 1 0 0");
	if ($? != 0)
	{
	    print ("\nNormalization Failed\n");
	    exit 1;
	}
}

#my $cur=1;
for my $f ( dir("$src")->children ) {
  next if $f->is_dir ;
 if ( $f->basename =~ /JPG$|JPEG|PNG$/i ) 
 {
  $extn= ($f->basename =~ /JPG|JPEG$/i) ? "jpg" : "png";
  my $exif = Image::ExifTool->new;
  $exif->ExtractInfo($f->stringify);
  my $date = $exif->GetValue('DateTimeOriginal', 'PrintConv');
  if (! defined $date)
  {
     if (! -d "$src/Analysis" )
     {
        `mkdir "$src/Analysis"`;
     }
     `mv "$f"  "$src/Analysis"`;
  }
  next unless defined $date;
  next if (defined $date && $ed==1);
  $date =~ tr[ :][T_];
  $date =~ tr[-][_];
  $date =~ s/_//g;
  $date =~ s/T/_/g;
  my $digest = md5_hex($f->slurp);
  $digest = substr($digest,0,9);
  my $nbasename= "$date".'_'."$digest";
  my $new_name = "$date".'_'."$digest.$extn";
  unless ( $f->basename eq $new_name ) {
    my $nndir=substr($new_name,0,4).'_'.substr($new_name,4,2);
    #print "\n$nndir";
    if (! -d "$tgt/$nndir" )
    {
      `mkdir "$tgt/$nndir"`;
    }
    if ( -f "$tgt/$nndir/$new_name" )
    {
       my $range = 88;
       my $rndd = int(rand($range)) +11;
       $new_name="$nbasename"."_"."$rndd.$extn";
    }
    `cp $f $tgt/$nndir/$new_name`;
     if ( $? ne 0 )
     {
        print "\n failed in cp $f $tgt/$nndir/$new_name\n";
        exit 1;
     }
    #rename $f => $new_name;
    my $da=`date +%Y%m%d_%H%M%S`; chomp($da);
    print "$da : copied $f => $tgt/$nndir/$new_name\n";
    #$cur++;
    #exit if ($cur >3);
  }
 }
}
