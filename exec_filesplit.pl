#!/usr/bin/perl -w
####################################################################################################
# Title         : Utility to Split a Large File into multple smaller sized files
#               : 
# FileName      : exec_filesplit.pl
#               : 
# Description   : The Purpose of script is to Split a Large File into multple smaller sized files
#               : read or written to by given edw bteq code
#               :
# Usage         : See help section
#               :
# Location      : $DW_BIN/exec_filesplit.pl
#               : 
# Return        : 0 - Successful 
#               : 1 - Failure
#               : 
# Created by    : Devesh Mohnani
#               : 
# Created On    : 2014-08-03
#               : 
# Modified      : 
#               : 
####################################################################################################
use strict;;use Time::Local; 
use POSIX qw(strftime);;use File::Basename; 
use Time::Local; 
use Env;
use Getopt::Long;

my $help='';
my $spl_bytes='';
my $odir='';
my $ifile='';
my $ifilepath='';
my $extn='';
my $ifile_ok='';
my $ifilefd;
my $ofilefd;
my $prefix='';
my $hremove=undef;
my $hneeded=undef;
my $actualsz='';
my $actualrc='';
my $filetype='';
my $rec_per_byte='';
my $rec_per_spl_file='';
my $tot_files='';

my $pwd=`pwd`; chomp($pwd);
my $scriptname = `basename $0`;chomp($scriptname); 
my $scriptpath = "$HOME/bin";
my $scriptnme2 = `basename $0`;chomp($scriptnme2); $scriptnme2 =~ s/\./_/g;
my $self=`who am i|cut -d ' ' -f1`; chomp $self;
my $num_arg = scalar(@ARGV);
my @cmd_line = @ARGV;
my $exitval=0;

my @date=split(/ /,`date "+%Y %m %d"`);
my @time=split(/ /,`date "+%H %M %S"`);
map { s/\s//g } @date;
map { s/\s//g } @time;
my $suffix="$date[0]". "-". "$date[1]". "-"."$date[2]". "_"."$time[0]" . "$time[1]" . "$time[2]" ;

my $logpath = "$HOME/log";
my $logfile = "$logpath/$scriptname" . '_' ."$suffix" . ".log";
my $logfd;

my $lc=0;
my $log_ok = open ($logfd, ">> $logfile" ) || die "Cannot open log file $logfile.";
print "\nLog File is : $logfile";
my $tstr=join (' ',@ARGV);
filelog("Command Line passed:\n $scriptname $tstr");

sub help
{
    print "
Help:
 +-------------------------------------------------------------------------------------------------------
 * Purpose: 
 *    This script splits a (large) file specified  into smaller sized files each of with size = byte_size
 *    records are not truncated while splitting the file.
 *
 * Usage:
 *    $scriptname -f </INPUT/FILE/PATH>  -o </OUTPUT/DIR> [-s <byte_size>] [-p <output_prefix>] [-r <yes>][-k <yes>]
 *    $scriptname -h
 *               -- Parameters inside square brackets are not mandatory
 * Parameters & flags:
 *         
 *         -f </INPUT/FILE/PATH>  =>  Specify Full path to input File (Large)
 *         -o </OUTPUT/DIR>       =>  Directory Path for dumping Output files
 *         -p <output_prefix>     =>  Name Prefix for Output Files
 *         -s <size in KB>        =>  Desired Size in Kilo Byte (KB) for each Output File (1 KB ~ approx 1000 Bytes)
 *                                     e.g. for size of approx 1 Mega Bytes (MB) use -s 1000 
 *         -r <yes>               =>  To remove Header from input file 
 *         -k <yes>               =>  To retain Header from input file in Splitted Files
 *
 *      -- [-p] Prefix is an optional parameter.
 *                        -- If no prefix is specfied , Input File name e.g. File.dat is appended with  
 *                           sequence number suffixes Ex. File_000001.dat, File_000002.dat ... (variable 0's based on file count)
 *                           File Extension (if present) is retained as is.
 *      -- [-s] Size (in KB) is an optional Parameter.
 *                        -- If no size is specified , 512 (KB) is taken as default size.
 *    HEADER related options:
 *      -- [-r] Remove header : This Flag is an optional parameter. 
 *                        -- If specified, First Record in the input file is assumed as Header Record, and
 *                        -- is removed before splitting file
 *      -- [-k] Keep header : This option requests program to keep HEADER from the Source File
 *                        -- If specified, header record is retained in each output file
 *         If neither of -r & -k not specified, Then No special handling for header is done
 *         (i.e. header Record will shows up only in first file)
 *   
 *      -- [-h] Print this Help
 +-------------------------------------------------------------------------------------------------------
";
 exit $exitval;
}
#--

sub filelog 
{
    my $arg   = shift;
    my $time  = localtime();

    my $timestamp;
    my(
       $second,  $minute,    $hour,      $dayofmonth, $month,
       $yearoff, $dayofweek, $dayofyear, $dst
    ) ;
    my $level = 0;

    # following checks are added to error out when
    # logfd is not defined or when it is not a file handle
    #
    if ( !defined $logfd ) {
        print "ERROR from filelog(): filelogfd not defined" ;
        return;
    }
    else {
        if ( !defined $logfd ) {
            print "ERROR from filelog(): logfd not a filehandle";
            return;
        }
    }

    if ( !defined $level ) {
        $level = 0;
    }
    (
       $second,  $minute,    $hour,      $dayofmonth, $month,
       $yearoff, $dayofweek, $dayofyear, $dst
    ) = localtime();

    $yearoff = $yearoff + 1900;
    $month   = $month + 1;

    $timestamp = sprintf( "\(%04d/%02d/%02d-%02d:%02d:%02d\): ",
                    $yearoff, $month, $dayofmonth, $hour, $minute, $second );

    print $logfd $timestamp;
    print $logfd "$arg\n";
}

#---
sub process_file
{
   print "\nINPUT FILE is : $ifile";
   filelog("INPUT FILE is : $ifile");
   $actualsz=`stat  -c %s $ifile`;
   if ($? ne 0)
   {
     print "Error: Can not stat $ifile\n";
     filelog("Error: Can not stat $ifile");
     exit (1);
   }
   $actualrc=`wc -l $ifile|cut -d ' ' -f1`;
   if ($? ne 0)
   {
     print "Error: Can not count records in $ifile\n";
     filelog("Error: Can not count records in $ifile");
     exit (1);
   }

   $filetype=`file $ifile`;

   if ($filetype =~ /empty/i)
   {
     print "\nError: Can not process empty File : $ifile\n";
     filelog("Error: Can not process empty File : $ifile");
     exit (1);
   }

   if ($filetype !~ /text/i)
   {
     print "\nError: Can not process, Not a Text File : $ifile\n";
     filelog("Error: Can not process, Not a Text File : $ifile");
     exit (1);
   }

   chomp($actualsz);
   chomp($actualrc);

   my $acszkb=int($actualsz/1024);
   print "\nActual Size:$actualsz ($acszkb KB)";
   filelog ("Actual Size:$actualsz ($acszkb KB)");

   print "\nActual lines:$actualrc";
   filelog("Actual lines:$actualrc");

   if($actualrc==0)
   {
     print "\nError: No or 1 record in input File : $ifile\n";
     filelog("Error: No of 1 record in input File : $ifile");
     exit (1);
     
   }
   $rec_per_byte=$actualrc/$actualsz;
   my $tbyt=$spl_bytes/1024;
   print "\nMax Size of splitted File: $tbyt KB\n";
   filelog ("Max Size of splitted File: $spl_bytes");

   $rec_per_spl_file=$rec_per_byte * $spl_bytes; 

   $rec_per_spl_file=1 if($rec_per_spl_file <1);

   my $trec_per_spl_file=int($rec_per_spl_file);
   print "Max Record Count of splitted file: $trec_per_spl_file\n";
   filelog("Max Record Count of splitted file: $trec_per_spl_file");

   my $tot_files1=$actualrc/$rec_per_spl_file;
   my $tot_files2=int($actualrc/$rec_per_spl_file);
   if($tot_files1 != $tot_files2)
   {
      $tot_files=$tot_files2+1;
   }
   else
   {
      $tot_files=$tot_files2;
   }
   print "Total number of splitted files: $tot_files\n";
   filelog("Total number of splitted files: $tot_files");

   # Now splitted pieces will have n lines each where n=

   open ($ifilefd , "<$ifile" ) || die "Cannot open data file $ifile";

   my $hread=0;
   my $header='';
   my $line='';
   if(defined $hneeded || defined $hremove)
   {
      $line=<$ifilefd>;
      $header=$line;
      $hread=1;
   }
   my $sufnum=1;
   my $sufpiece=length($tot_files);
   
   for (my $i=1; $i<=$tot_files ; $i++)
   {
      my $fsuffix=sprintf("%0${sufpiece}s", $sufnum);
      my $ofilename='';
      if(defined $odir && $odir ne '')
      {
         $ofilename= $odir .'/'. $prefix . $fsuffix .$extn;
         $ofilename=~ s/\/\//\//g
      }
      else
      {
         $ofilename= $ifilepath .'/'. $prefix . $fsuffix .$extn;
         $ofilename=~ s/\/\//\//g
      }
      my $lng=length($tot_files);
      my $fmsg=sprintf("%s%${lng}d%s", "Output File ", $i ,": $ofilename");
      #print "\n$fmsg";
      filelog("$fmsg");
      
      open ($ofilefd , ">" ,"$ofilename") || die "Cannot create file $ofilename";
      my $j=1;
      if(defined $hneeded)
      {
          print $ofilefd $header;
          $j++;
      }
      for (; $j <= $rec_per_spl_file && defined ($line);$j++)
      {
         $line=<$ifilefd>;
         print $ofilefd $line if (defined $line);
      }
      close($ofilefd);
      $sufnum++;
   } 
   
   close($ifilefd);
   return(0);
}


# main()
if ( $num_arg == 0 ) 
{
   print "\nError: No Arguement was specified.\n";
   filelog("Error: No Arguement was specified.");
   $exitval=1;
   &help();
} 
else 
{
   GetOptions(
	          'help|h'   => \$help,
                 'ifile|f=s' => \$ifile,
	          'size|s=s' => \$spl_bytes,
                  'odir|o=s' => \$odir,
                'prefix|p=s' => \$prefix,
         'remove_header|r=s' => \$hremove,
           'keep_header|k=s' => \$hneeded,
    );
   if($help)
   {
       &help();
   }

   if ($ifile eq '' or !(-f $ifile))
   {
     print "\nError: No or incorrect input file is specified";
     filelog("Error: No or incorrect input file is specified");
     if ($ifile eq '')
     {
        print ".\n";
     }
     else
     {
        print ". Please check input file $ifile.\n";
        filelog("Please check input file $ifile.");
     }
     $exitval=1;
     &help();
   }
   my $tifile=$ifile;
   $tifile=~s/(.*\/)(.*)/$2/g;
   $ifilepath=$1;
   $tifile=$ifile;
   
   if (!(-d $odir) or -f $odir)
   {
     if($odir eq '')
     {
        print "\nWarning: No output directory is specified. Source Dir is taken as output dir.\n";
        filelog("Warning: No output directory is specified. Source Dir is taken as output dir.");
        $odir=$ifilepath;
     }
     else
     {
        print "\nError: Incorrect output dir is specified, Please check output dir $odir. \n";
        filelog ("Error: Incorrect output dir is specified, Please check output dir $odir.");
        $exitval=1;
        &help();
     }
   }

   if ($prefix eq '' ) 
   {
     print "Warning: No Output file prefix is specified, will use source file name as prefix.\n\n";
     filelog("Warning: No Output file prefix is specified, will use source file name as prefix.");
     $tifile=~s/(.*)\/(.*)/$2/g;
     $tifile=~m/^(.*)\.(.*)/g;
     $prefix=$1 . "_";
     $extn='.'.$2;
   }
   else
   {
     $tifile=~s/(.*)\/(.*)/$2/g;
     $tifile=~m/^(.*)\.(.*)/g;
     #$prefix=$1 . "_";
     $extn='.'.$2;
   }

   if(!($prefix =~ /_$/))
   {
     $prefix .= '_';
   }

   $prefix=~s/\s/_/g;
   print "\nPrefix is : $prefix";
   filelog("Prefix is : $prefix");

   if ($spl_bytes eq '')
   {
      $spl_bytes=512*1024; #512 KB
   }
   $spl_bytes =~ s/[^0-9]+//g;
   $spl_bytes=$spl_bytes*1024;
   if(defined $hremove && defined $hneeded)
   {
     print "Error: Can not specify together to Keep and remove the header.\n"; 
     filelog ("Error: Can not specify together to Keep and remove the header.\n"); 
     $exitval=1;
     &help();
   }
}

$exitval=process_file();
if ($exitval == 0)
{
  print "\nSuccess: File Split Operation Completed Successfully.";
  print "\nLog File is : $logfile";
  filelog("\n");
  filelog("Success: File Split Operation Completed Successfully.");

  print "\n\nExiting ... 0\n";
  close($logfd);
  exit($exitval);
}
#------------------------------------------


