#!/usr/bin/perl

use lib '/home/root/bin';
use MIME::Lite;
use File::Basename;
use Time::Local; 
use POSIX qw(strftime);
use File::Basename; 
use Time::Local; 
use File::stat;
#use File::Cmp;
use FileRoutines; 


my $fun_num    = $ARGV[0];  # nd|nf
my $dirname    = $ARGV[1];  # /path/to/dir
my $mailflag   = $ARGV[2];  # to mail (1) 
my $namelength = $ARGV[3];  # length limit (20)
my $testflag   = $ARGV[4];  # preview flag (1)
my $fulltrim   = $ARGV[5];  # Full Trim (1)

if($mailflag   eq '') {$mailflag   =0}
if($namelength eq '') {$namelength =0}
if($testflag   eq '') {$testflag   =0}
if($fulltrim   eq '') {$fulltrim   =0}

print "\nACTION=$fun_num,\nDIRNAME=$dirname,\nMAILFLAG=$mailflag,\nNAMELENGTH=$namelength,\nPREVIEW=$testflag\nFULLTRIM=$fulltrim\n\n";

my $scrname=`basename $0`;
chomp($scrname);

if (!(defined $dirname && -d $dirname))
{
 print "\nUsage: " . $scrname  . ' <nd|nf> <Path> <mailflag> <namelength> <previewflag> <fulltrim>' ."\n\n";
 exit 1;
}

#sleep 1;

#($dirname,$mailflag,$length)
&FileRoutines::ns_dns_in_a_dir  ($dirname,$mailflag,$namelength,$testflag,$fulltrim) if ($fun_num eq 'nd');
&FileRoutines::ns_fns_in_a_dir  ($dirname,$mailflag,$namelength,$testflag,$fulltrim) if ($fun_num eq 'nf');

