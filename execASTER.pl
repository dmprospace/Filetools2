#!/usr/bin/perl

####################################################################################################
# Title         : Wrapper for calling ASTER jobs from command line
#               : 
# FileName      : execASTER.pl
#               : 
# Description   : This script is a wrapper that calls ASTER jobs from the command line and provides
#               : logging of execution status in Run Table
#               :
# Usage         : execASTER.pl [Options] <fileName|fileList> [Parameters]
#               : [Options] - Switches for controlling program options
#               : <fileName|fileList> - Name of ASTER file to execute or name of file that 
#               :                       contains a list of ASTER scripts to execute
#               : [Parameters] - List of Name=Value parameters to override defaults
#               :
#               : See Usage() subroutine within script body for Detailed Usage info 
#               : 
# Location      : 
#               : 
# Return        : 0 - Successful 
#               : 1 - Incorrect options passed
#               : 2 - Invalid fileName or fileList 
#               : 4 - Invalid Parameters
#               : 8 - Other Error
#               : 16- Other ASTER Error
#               : 
# Dependencies  : Requires the following environmental varibles to be set -
#               : $DW_LOG - Location to put logs
#               : $SUNOPSIS - Location of Sunopsis binaries/programs 
#               : 
#               : Requires the Following Standard or CPAN Perl Modules -
#               : Getopt::Std
#               : File::Basename
#               : Tie::File
#               : Fcntl
#               : 
#               : Requires the Following Non Standard Perl Modules  
#               : FileLib
#               : CalcDateTime
#               : CheckQuotes
#               : 
#               : 
# Developer     : Devesh Mohnani
#               : 
# Created On    : 2015-04-15 (See TD-16586)
#               : 
####################################################################################################

use strict;

BEGIN {
    # Pull in environmental variables from user running script
    use Env qw(DW_HOME DW_LOG DW_TMP DW_SQL DW_LIB DW_BIN SUNOPSIS DWDB); 
}
my $logfile ='';
my $tmpinsfile="/tmp/.execASTER.$$.ins";
my $tmplogfile="/tmp/.execASTER.$$.log";
my $globalRV=-9999;
$SIG{INT} = sub { $globalRV=1; cleanuptemp() };

# Define library Location
use lib qq{$DW_LIB};

### Use Libraries ###
use Getopt::Std; # Used to process Switches passed at runtime
use File::Basename;
use execASTERFileLib;
use CalcDateTime; # Used throughout program to make getting times easier
use Tie::File; # Need this for Checking $logfile for errors
use Fcntl qw(:DEFAULT :flock); # Need this for Checking $logfile for errors
use CheckQuotes; # Used to prepare SQL for insert

# Define Constants for Return Codes
# Since Constants don't work as expected, well just use vars in all caps to emulate
our $EXIT_OK = 0;
our $EXIT_BAD_OPTIONS = 1;
our $EXIT_BAD_FILE = 2;
our $EXIT_BAD_PARAMETERS = 4;
our $EXIT_OTHER_ERROR = 8;
our $EXIT_ASTER_ERROR = 16;

# HARD CODED PROGRAM SWITCHES
our $gDebug = 0; # Used to turn on instrumentation for troubleshooting
our $gDisableLoggingFlag = 1; # Use this to determine if logging should be on (0) or off (1) by default

# Global Variables for controlling behavior of program
our $gShowHelp = 0; # Flag for displaying help and exiting
our $gNoExecute = 0; # Flag to bypass call to ASTER (Will generate File but not execute)
our $gStopOnError = 1; # Will force program to abort execution on errors
our $gDisableRunTable = 0; # Flag to disable writing to Run table
our $gDisableLogging = $gDisableLoggingFlag; # Flag to disable writing to Log Files
our $gDisableErrorCheck = 0; # Flag to disable Checking ASTER Logs
our $gExecFilelist = 0; # Flag to execute File List
our $gPersistentFiles = 0; # Prevents files from being deleted that were generated
our $gVerbose; # Flag for Verbose Output/Debugging
our $gDisableOutput = 0; # Flag for Disabling program output in logit routine
our $gInstanceID = 0; # Flag for Generating Instance ID
our $gFinalizeInstanceID = 0; # Flag for Finalizing Instance ID Run
our $gRunTable = 0; # Flag for Signaling Run Table Processing
our $gRunTableErrors = 0; # Flag to signal errors writing to run table
our $gASTERErrors = 0; # Flag to signal errors running ASTER Script
our $scriptName = basename($0);
our $perl = "/usr/bin/perl";
our $loggingSetup = 0; # Flag to indicate if logging has been setup (Logs opened and "hot")
our $gQueryBand = ""; #  Variable to hold Query Band information
our $gPrintQueryBand = 0; #  Flag to signal displaying Query Band info
our $gUser = ""; #  Variable to hold alternate user
our $gUserName = ""; #  Variable to hold actual user from Credentials file
our $gJobType = "ASTER"; #  Variable to hold Job Type for Run Table
#our $actCmd='/home/beehive/clients/act';
our $actCmd="$ENV{DW_HOME}/lib/act/act";
our $asterHost='10.4.22.55';
if ($gDebug)
{ 
    # Enable Verbose output automatically if debug is on
    $gVerbose = 1;
}
else
{
    $gVerbose = 0; # Default Value
}

# Define other variables/arrays and hashes we'll use throughout the code
our @files;


# The RunTable Hash contains all the data that will be inserted into the run table
# This will end up being a Hash of a Hash. If a filelist was passed in it will have a 
# {0} for the parent subhash and then a count {1},{2}... subhash for each child script
# If we are just dealing with a single ASTER we should have been passed a PARENT that 
# will get set. If no PARENT was passed, we'll use the IID as the PIID  
our %RunTable;

# This is the fully qualified name of the run table within Teradata
#our $RUNTABLE = "$DWDB.etl_run"; # This is the OLD run table 
our $RUNTABLE = "OPSDATA.etl_run"; # 

# This is a queue file that will store all the run table data that could not be
# inserted into the run table at runtime due to errors/problems
# We will attempt to reprocess this file periodically by a seperate process
our $runTablePrefix = "runTableASTER";
our $RunTableFile = "$DW_TMP/$runTablePrefix.queue.sql";

# This is the number of times we'll try to write to Run Table
our $RetryCnt = 3;

# Define Variable for IID (used for instance_id in run table)
# UUID will look like this - $epochtime.$pid$iidcount
our $epochtime = $^T; # Get the epoch time
our $pid = $$; # Get the PID (Can only have a single PID in any given second)
our $iid_count = 1; # This is used to append on the end of our Unique ID
our $instanceID; # This is used if we are generating or finalizing instance id's

# Define and set time execution starts (for logging, filename, etc...)
our ($sec,$min,$hour,$mday,$mon,$year,$usec) = CalcDateTimeHR();

# Define the logfile name and location
our $RUNLOGDIR = $DW_LOG . "/execASTER";
our $RUNLOGFILE = "$RUNLOGDIR/$scriptName.$year$mon$mday" . "_$hour$min$sec" . "_$pid.log";

# Setup and open logfiles if on by default
setupLogging() unless $gDisableLogging;

if ($gDebug)
{
    # Let's print out all our starting variables
    logit("Executing in Debug Mode!\n\n");
    logit("Show Help            => $gShowHelp\n");
    logit("No Execute           => $gNoExecute\n");
    logit("Persistent Files     => $gPersistentFiles\n");
    logit("Stop On Error        => $gStopOnError\n");
    logit("Disable Run Table    => $gDisableRunTable\n");
    logit("Disable Logging      => $gDisableLogging\n");
    logit("Disable Output       => $gDisableOutput\n");
    logit("Disable Error Check  => $gDisableErrorCheck\n");
    logit("Verbose Output       => $gVerbose\n");
    logit("Use File List        => $gExecFilelist\n");
    logit("Instance ID          => $gInstanceID\n");
    logit("Finalize Instance ID => $gFinalizeInstanceID\n");
    logit("Run Table Signal     => $gRunTable\n");
    logit("Query Band Info      => $gQueryBand\n"); # 
    logit("Query Band Info Flag => $gPrintQueryBand\n"); # 
    logit("User Name            => $gUser\n"); # 
    logit("Job Type             => $gJobType\n\n"); # 
}

### Begin Program Flow 

### BEGIN block has already executed ###

# Keep a copy of the command line arguments so we can register them in the run table.
my @argument_list=();
my $allArgs;
map {$allArgs .= "$_ "} @ARGV;
my $lll=0;
foreach (@ARGV) { push (@argument_list,"$lll : $_");$lll++}
 
# Lets go get the Command line arguments and load them into the options hash
our %options = parseCommandLine();

# This prints a copy of command line arguments
logit("allArgs(\@ARGV) => $allArgs\n") if $gDebug;

# Check and see if Instance ID was requested
if ($gInstanceID)
{
    # Instance ID was requested, go generate one and exit
    $instanceID = getInstanceID();

    # Print instanceID back to requestor
    print "$instanceID";

    # Overwrite Job Type  if not specified
    unless ($options{t})
    {
        $gJobType = "SCHEDRUN";
    }

    # Get ready to insert into Run Table
    my $RunTableScript = beginInstanceID($instanceID);

    # Let's go execute the script we have just prepared
    processRunTable($RunTableScript);

    # No Further execution is needed, Let's Exit
    exitBlock($EXIT_OK);
}

# Check and see if Finalize Instance ID was requested
if ($gFinalizeInstanceID)
{
    # Finalize Instance ID was requested, get passed ID and process
    $instanceID = $options{fileName};

    unless ($instanceID =~ m/^\d+$/)
    {
        logit("Invalid instanceID '$instanceID' passed to " . basename($0) . "\n");
        Usage();

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 
        exitBlock($EXIT_BAD_OPTIONS);
    }

    # Get ready to update Run Table
    my $RunTableScript = finalizeInstanceID($instanceID);

    # Let's go execute the script we have just prepared
    processRunTable($RunTableScript);

    # No Further execution is needed, Let's Exit
    exitBlock($EXIT_OK);
}

# Now let's go load the parameters into the environment
###############################################################################
# These can be specified at two levels
# 1) Variables exported to the shell ENV parameters
# 2) Passed at runtime on the command line. Variables passed at runtime
# will take precidence over those found in the ENV.
###############################################################################
# Don't want to use the ENV hash as this has conncurrecy issues
# so we'll load everything into %parameters to keep from clobbering %ENV
my %parameters = loadParameters(\%{ $options{parameters} });

# Let's see what type of fileSpec was passed and act appropriatly
if ($options{fileName} =~ /\.flst$/)  
{
    logit("In Legacy File List Mode...\n") if $gVerbose;

    # This is a legacy hack. The original program used a filelist if the extension
    # was .flst This has been rewritten to use a flag to initiate this action. 
    # We do a check on the filename and see if it was passed in as flst, if it was
    # we set the flags accordingly so the rest of the program behaves as it should
    $gExecFilelist = 1;
    $options{f} = 1;
}

# Now we need to find out if we are executing a filelist or a single file
if ($gExecFilelist)
{
    # Looks like we are executing a filelist. Now we'll go validate they exist
    logit("Processing File List...\n") if $gDebug;

    @files = processFileList($options{fileName});  

    # Check to see if we found and were able to read from filelist
    if ($files[0] == $EXIT_BAD_FILE)
    {
        logit("Could not find the filelist: $options{fileName}\n");
        logit("Either $options{fileName} does not exist or ");
        logit("$DW_HOME/aster/sql/$options{fileName} does not exist\n");

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 

        exitBlock($EXIT_BAD_FILE);
    }
    elsif ($#files == -1)
    {
        logit("Could not locate the files listed in $options{fileName}\n");

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 

        exitBlock($EXIT_BAD_FILE);
    }

    # Looks like we found the files, let's proceed
    if ($gDebug)
    {
        logit("Filelist file $options{fileName} contains the following valid lines -\n");

        my $iTmp = 1;
        foreach (@files)
        {
            chomp;
            logit(" $iTmp\) $_\n");
            $iTmp++;
        }
    }
}
else
{
    # Looks like we are executing a single file, let's do some quick validation
    logit("Checking File...\n") if $gDebug;

    # This routine will check to see if the file exists and return the name if it does
    @files = getLegalFileNames($options{fileName},"$DW_HOME/aster/sql");

    # Check to see if we found the file
    if ($files[0] == $EXIT_BAD_FILE)
    {
        logit("Could not find the file: $options{fileName}\n");
        logit("Either $options{fileName} does not exist in current directory ");
        logit("or $DW_HOME/aster/sql/$options{fileName} does not exist\n");

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 

        exitBlock($EXIT_BAD_FILE);
    }

    # Looks like we found the files, let's proceed
    if ($gDebug)
    {
        # @files should only contain one file here but print array just in case
        foreach (@files)
        {
            chomp;
            logit("   Found File: '$_'\n");
        }
    }
}

# This is where the logic in this version will begin to drastically change from 
# the original version. The original version started hitting the run table immediately
# We are going to cache all of that info and only do it once to avoid the contention 
# on the run table and to help with performance.
# Also any lineage processing will be kept in the PIID and IID (you will have to walk the
# Parent/Child (PIID/IID respecivly) in the run table to get lineage.

our $hierarchy = 0;

# If we were passed a filelist then it will become a parent also so we need to do some
# extra processing here to deal with multiple levels
if ($gExecFilelist && !$gRunTable) # Don't execute if we are just processing run table
{
    # We are running a fileList that will have multiple ASTER scripts executed. 
    # Let's start populating the %RunTable Hash with the parent info for all the
    # child jobs that will be spawned
    # RUNTABLE Columns -
    # Instance_id,Parent_id,Script_name,run_start_dttm,Run_end_dttm,Status
    # Parameters,Lineage,Error_message,Resolution,Create_DTTM,Last_update_Dttm
    # Last_Update_user

    # This generates a Unique id (epochtime.PID$COUNT Numbers are padded with 0's)
    $RunTable{$hierarchy}{IID} = getInstanceID();
    $RunTable{$hierarchy}{fileName} = $options{fileName};
    $RunTable{$hierarchy}{StartDTTM} = "$year-$mon-$mday $hour:$min:$sec.$usec";
    $RunTable{$hierarchy}{Args} = $allArgs;
    $RunTable{$hierarchy}{Status} = 'C'; # Flag as complete, will get flipped to E if erros encountered
    $RunTable{$hierarchy}{JobType} = $gJobType; #  Set Job Type

    # Set PIID to the passed PARENT if available
    if (exists $parameters{PARENT})
    {
        # Split on '/' in case legacy format was passed in 
        my @parent = split(/\//,$parameters{PARENT});
        $RunTable{$hierarchy}{PIID} = $parent[-1];
    }
    else
    {
        # This is the Parent, so these match
        $RunTable{$hierarchy}{PIID} = $RunTable{$hierarchy}{IID}; 
    }

    # Incement this as we've already started to populate the first level
    # and do not want to overwrite it
    $hierarchy++;
}

# We are now ready to start processing all the ASTER files found in @files
# This will be a single file unless were doing a filelist (-f or .flst file)
foreach (@files)
{
    chomp;

    # Set variable to make references easier in code
    my $ASTER = $_;

    logit("Processing ASTER: $ASTER") if $gVerbose;

    # Get Loop starting execution Time
    # This will be populate run_start_dttm in run table
    my ($Sec,$Min,$Hour,$Mday,$Mon,$Year,$Usec) = CalcDateTimeHR();

    unless ($gRunTable) # Don't execute if we are just processing run table
    {
	    # This used to get assigned from the EDW. We do it here now to help with performance and 
	    # to minimize calls to the database
	    $RunTable{$hierarchy}{IID} = getInstanceID();
	
        # Need to go set the PIID appropriatly
        if (exists $parameters{PARENT} && $hierarchy == 0)
        {
            # Want to used Parent IID that was passed in 

            # Split on '/' in case legacy format was passed in 
            my @parent = split(/\//,$parameters{PARENT});

            $RunTable{$hierarchy}{PIID} = $parent[-1];
        }
        elsif ($hierarchy > 0 && $gExecFilelist)
        {
            # Want to keep IID of flst passed as Parent IID
            $RunTable{$hierarchy}{PIID} = $RunTable{0}{IID};
        }
        elsif ($hierarchy > 0)
        {
            # Want to use previous IID as PIID if in hierarchy
            $RunTable{$hierarchy}{PIID} = $RunTable{$hierarchy - 1}{IID};
        }
	    else
	    {
	        # Previous PIID was not set, let's use this IID as a parent
	        $RunTable{$hierarchy}{PIID} = $RunTable{$hierarchy}{IID};
	    }
	
	    $RunTable{$hierarchy}{StartDTTM} = "$Year-$Mon-$Mday $Hour:$Min:$Sec.$Usec";
	    $RunTable{$hierarchy}{fileName} = $ASTER;
        $RunTable{$hierarchy}{Args} = $allArgs;
    }

    # Make sure this is called after getInstanceID so $iid_count get's incremented
    my $suffix = getSuffix(); 

    ###################################################################################
    # The Following code logic was contained in the executeOneSQLFile routine in 
    # the previous version since it's not reusable outside this we are doing it inline
    ###################################################################################

    logit("\n$Hour:$Min:$Sec.$Usec - Processing $_\n") unless $gRunTable;

    # Build the logfile location variable
    $logfile = "$DW_LOG/" . getFileRoot($ASTER) . $suffix . '.log';
    `touch $tmpinsfile $tmplogfile $logfile >/dev/null 2>&1`;
    unless ($gRunTable)
    {
        logit("\n---> ASTER Log File: $logfile\n\n");
        logit("---> RUN Log File: $RUNLOGFILE\n\n") unless $gDisableLogging;
    }

    # Build the Instance Script. This will go and replace all variables in the ASTER
    # with the values and write the new SQL out to a file that ASTER can execute
    my $instanceScript = makeInstanceScript($ASTER, $suffix);

    logit("   Instance Script is at: $instanceScript\n") if $gVerbose;

    # This will go gather the Credentials and build a ASTER command file that includes
    # the Credentials and the Instance Script as the file to execute
    my $cmdFile = makeCommandFile($instanceScript, $suffix);

    logit("   Command File is at: $cmdFile\n") if $gVerbose;

    # , Add User Name to RunTable Hash - gUserName is set from makeCommandFile routine above
    $RunTable{$hierarchy}{UserName} = $gUserName;

    #  Add Job Type to RunTable Hash (Provided at runtime or uses Default setting)
    $RunTable{$hierarchy}{JobType} = $gJobType;

    # Check to see if we are in Execute Mode or not
    if ($gNoExecute)
    {
        # We don't want to execute anything against the EDW, but do want these available
        # for inspection so we won't delete the files
        logit("\nFinished preparing ASTER for execution but No Execute (-n) was requested!\n");
        logit("The following files were generated -\n");
        logit(" ASTER     -> $ASTER\n");
        logit(" Instance -> $instanceScript\n");
        logit(" Command  -> $cmdFile\n\n");
    }
    else
    {
        logit("\nInvoking ASTER to execute Command File!\n") if $gDebug;

        # Let's go execute the script and send the log to $logfile
        # We want to do this in a shell process, so were calling system to invoke it
        # This will invoke ACT and redirect all output to $logfile
        my ($ac,$ah,$au,$ap)=split(/ /,`grep '.LOGON' $cmdFile | tr ';' ' ' |tr ',' ' ' |tr '/' ' '` );
        system("$actCmd -E -h $ah -U $au -w $ap -d poast1 < $instanceScript >> $tmplogfile 2>&1");
        $globalRV=$?;
        
        open (FHH, "<$instanceScript") or die "Cant open $instanceScript";
        my @all_lines=<FHH>;
        close FHH;
        open (FHH, ">$instanceScript") or die "Cant open $instanceScript";
        foreach(@all_lines)
        {
            if ($_ =~ /password/i)
            {
               $_=~ s/(password)(.*?)('.*?')(.*?)/$1$2'*****'$4/ig;
               
            }
            print FHH "$_";
        }
        close FHH;
        foreach (@argument_list) 
        { 
           if ($_ =~ /^0/)
           {           
             `echo FileName $_ >>$logfile`
           }
           else
           {
             `echo Argument $_ >>$logfile`
           }
        }
        `cat $logfile        > $tmpinsfile  2>&1`;
        `cat $instanceScript >> $tmpinsfile  2>&1`; 
        `echo " "            >> $tmpinsfile  2>&1`;
        `cat $tmplogfile     >> $tmpinsfile  2>&1`;
        `cat $tmpinsfile     > $logfile  2>&1`;        
    }

    unless ($gRunTable)
    {
        # Let's update the execution end time variables
        # before we start thrashing on logs
        ($Sec,$Min,$Hour,$Mday,$Mon,$Year,$Usec) = CalcDateTimeHR();
    
        # This will populate run_end_dttm in the Run Table
        $RunTable{$hierarchy}{EndDTTM} = "$Year-$Mon-$Mday $Hour:$Min:$Sec.$Usec";
    }

    # , Add SessionID to RunTable Hash
    $RunTable{$hierarchy}{SessionID} = extractSessionID($logfile);

    unless ($gDisableErrorCheck)
    {
        # let's go check and see if we encountered any errors during execution
        my $errMsg = checkForASTERErrors($logfile);

        if ($errMsg eq 0)
        {
            logit("ASTER Log Parse Returned - $errMsg\n\n") if $gVerbose;

            # No errors were encounted. Let's update the RunTable hash and proceed
            $RunTable{$hierarchy}{Status} = 'C' unless $gRunTable;
        }
        else
        {
            # Errors were encountered, let's print them back to caller
            logit("\n$errMsg\n\n");

            unless ($gRunTable)
            {
                # Looks like we had an error, Let's update the %RunTable Hash 
                $RunTable{$hierarchy}{Status} = 'E';
                $RunTable{$hierarchy}{Error} = $errMsg;

                # Check to see if this is a child, if so update the parent with
                # a Status = E
                if ($RunTable{$hierarchy}{IID} ne $RunTable{$hierarchy}{PIID})
                {
                    # Parent should always be node 0 in Hash
                    $RunTable{0}{Status} = 'E';
                }
            }

            # Let's turn on the Persistent Files flag to keep all files since
            # we encountered errors
            $gPersistentFiles = 1;

            # Check to see if we should continue or exit
            if ($gStopOnError)
            {
                # Requested to stop, Let's go write out the %RunTable Hash to the 
                # EDW and exit
                logit("$Hour:$Min:$Sec.$Usec - Processing has been aborted due to errors while executing $ASTER\n");

                # This will print all the values currently in the runTable Hash
                printRunTableHash() if $gDebug;

                exitBlock($EXIT_ASTER_ERROR);
            }
        }
    }
    else
    {
        # Error Check was disabled, so let's just mark it as complete in run table
        $RunTable{$hierarchy}{Status} = 'C';
    }

    # Check and see if we should delete generated Files
    unless ($gPersistentFiles)
    {
        if ($gVerbose)
        {
            logit("Removing The Following Files-\n");
            logit("   $instanceScript\n");
            logit("   $cmdFile\n");
            logit("   $ASTER\n") if $gRunTable;
        }

        unlink($instanceScript);
        unlink($cmdFile);

		if ($gRunTable)
		{
		    # This is a runtable execution, let's delete the ASTER as well
            # Added this regex as a failsafe to keep from deleted user submitted files inadvertantly
	        if ($ASTER =~ m/$runTablePrefix/)
		    {
		        # $ASTER matches runTableASTER file name pattern, ok to delete
	            unlink($ASTER);
		    }
		}
    }

    # Increment hierarchy count for RunTable Hash 
    $hierarchy++;
}

# This will print all the values currently in the runTable Hash
printRunTableHash() if $gDebug;


# Don't want to print this if we are processing run table
unless ($gRunTable) 
{
    ($sec,$min,$hour,$mday,$mon,$year,$usec) = CalcDateTimeHR();
    logit("$hour:$min:$sec.$usec - Completed.\n");
}

# All processing has finished, Let's Exit
if ($gASTERErrors)
{
    # Signal an error occured even if -c was passed (we would have already
    # exited before here without -c option)
    exitBlock($EXIT_ASTER_ERROR);
}
else
{
    # Everything looks good, Were Done
    exitBlock($EXIT_OK);
}

### END PROGRAM ###

### Begin Subroutines ###

# Print Usage/Help
sub Usage {
    my $shortUsage = "\n"; 
    $shortUsage .= "Usage: execASTER.pl [-cefhiIlnopqQrtuvVz] fileName|InstanceID [Parameters]\n";
    $shortUsage .= "Wrapper for calling ASTER jobs from the command line\n\n";

    my $longUsage = "";
    $longUsage .= " -c              Continue on Errors\n";
    $longUsage .= " -e              Disable ASTER Error Check\n";
    $longUsage .= " -f              Use File List.\n";
    $longUsage .= " -h              Display help and exit (This)\n";
    $longUsage .= " -i              Generate Instance ID and exit\n";
    $longUsage .= " -I              Finalize Instance ID Group Execution\n";
    $longUsage .= " -l              Enable Logging (Directs SYSOUT to logfile and screen)\n";
    $longUsage .= " -n              Don't Execute (Generate Syntax Files Only Enables -p)\n";
    $longUsage .= " -o              Disable Output (Disables most output to STDOUT)\n";
    $longUsage .= " -p              Persistent Files (Syntax Files will exist after execution)\n";
    $longUsage .= " -q              Display Query Band Information\n";
    $longUsage .= " -Q <NAME=VALUE> Supplemental Query Band (Must be enclosed in Quotes!)\n"; # 
    $longUsage .= " -r              Signal Run Table Processing (Enables -z)\n";
    $longUsage .= " -t <JobType>    Specify Job Type for Run Table Entry (Default is ASTER)\n"; # 
    $longUsage .= " -u <UserName>   Execute as User <UserName>\n"; # 
    $longUsage .= " -v              Verbose Output\n";
    $longUsage .= " -V              Very Verbose Output (Debug Mode)\n";
    $longUsage .= " -z              Disable logging to Run Table\n";
    $longUsage .= "\n";
    $longUsage .= " fileName|InstanceID  Name of ASTER script, File List or InstanceID to execute (Required)\n";
    $longUsage .= " [Parameters]  Name Value Paramater List (Name=Value). Multiple Values can be";
    $longUsage .= " seperated by a space\n\n";
    $longUsage .= "This program is a wrapper that calls ASTER scripts and executes them against ";
    $longUsage .= "the\nTeradata EDW. This adds the ability to record execution within the ";
    $longUsage .= "database run\ntable and also handles error logging and output for the ";
    $longUsage .= "Enterprise Scheduling Tools.\n\n";

    my $Usage = $shortUsage;
    $Usage .= $longUsage if ($gShowHelp);

    print "$Usage";
}

# Loads command line parameters and options into hash
sub parseCommandLine {

    logit("\nParsing Command Line Arguments...\n") if $gDebug;

    # Get any options that were passed
    my %options;

    # This needs to have all the valid switches listed. If a switch was passed that is 
    # not defined here the program will return a Invalid Options error
    #   Options with a trailing : indicate they require an argument to be passed in 
    my $ok = getopts("cefhiIlnopqQ:rt:u:vVz",\%options);

    # Getoptions will return True unless invalid options were passed
    unless ($ok)
    {
        logit("Invalid options passed to " . basename($0) . "\n");
        Usage();

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 

        exitBlock($EXIT_BAD_OPTIONS);
    }

    # Check to see how script was called, These are Legacy Hacks put in place in case
    # we don't use a wrapper script and just do symbolic links back to this file
    if ($scriptName =~ /^getRunInstanceID\.pl$/i)
    {
        logit("In Legacy getRunInstanceID.pl Mode!\n") if $gDebug;

        # Flip the bit as if -i was passed
        $gInstanceID = 1;
    }

    if ($scriptName =~ /^finalizeRunInstanceStatus\.pl$/i)
    {
        logit("In Legacy finalizeRunInstanceStatus.pl Mode!\n") if $gDebug;

        # Flip the bit as if -I was passed
        $gFinalizeInstanceID = 1;
    }

    # getoptions parsed OK, Let's go set values based on passed options
    $gExecFilelist = 1 if $options{f}; # Use File List
    $gShowHelp = 1 if $options{h}; # Display Help and Exit
    $gInstanceID = 1 if $options{i}; # Generate Instance ID and Exit
    $gFinalizeInstanceID = 1 if $options{I}; # Finalize Instance ID processing
    $gNoExecute = 1 if $options{n}; # Generate ASTER Files, but don't execute
    $gDisableErrorCheck = 1 if $options{e} || $gNoExecute; # Suppress Checking ASTER Errors
    $gPersistentFiles = 1 if $options{p} || $gNoExecute; # Keep generated Files
    $gRunTable = 1 if $options{r}; # Signal Run Table Processing
    $gStopOnError = 0 if $options{c}; # Do not stop executing if errors are encountered
    $gStopOnError = 1 if $gRunTable; # Override -c switch if -r was passed
    $gVerbose = 1 if $options{v}; # Verbose output
    $gVerbose = 2 if $options{V}; # Very Verbose output (Debug Mode)
    $gDisableOutput = 1 if $options{o}; # Disables STDOUT in logit
    $gDisableRunTable = 1 if $options{z} 
                            || $gRunTable 
                            || $gShowHelp 
                            || $gInstanceID 
                            || $gFinalizeInstanceID 
                            || $gNoExecute; # Do not log to Run Table
    $gQueryBand = $options{Q} if $options{Q}; #  Query Band Info
    $gPrintQueryBand = 1 if $options{q}; #  Print Query Band Info
    $gUser = $options{u} if $options{u}; #  User
    $gJobType = $options{t} if $options{t}; #  Job Type

    # Check to see how we are handling logging
    # NOTE: This is only system/sysout logging. Even if disabled ASTER logs and checks will
    # still act according to program flags!
    if ($gDisableLoggingFlag)
    {
        # Use this if logging is disabled by default
        $gDisableLogging = 0 if $options{l}; # Enable writing to Log Files
    }
    else
    {
        # Use this if logging is enabled by default
        $gDisableLogging = 1 if $options{l} || $gNoExecute || $gRunTable; # Suppress writing to Log Files
    }

    # Check and see if logging was requested($gDisableLogging), setup now if not already done ($loggingSetup)
    setupLogging() unless $gDisableLogging || $loggingSetup;

    # Check to see if debugging is on, enable it if requested
    unless ($gDebug)
    {
        # Turn on debug flag if Very Verbose option was passed
        if ($gVerbose > 1)
        {
            logit("\nEnabling Debug Mode...\n");

            $gDebug = 1;
        }
    }

    ### Done checking switches ###

	if ($gDebug)
	{
	    # Let's print out all our variables again now that options are set (DEBUG MODE ONLY)
        logit("\nOptions after getops has run -\n\n");
	    logit("Show Help            => $gShowHelp\n");
	    logit("No Execute           => $gNoExecute\n");
	    logit("Persistent Files     => $gPersistentFiles\n");
	    logit("Stop On Error        => $gStopOnError\n");
	    logit("Disable Run Table    => $gDisableRunTable\n");
	    logit("Disable Logging      => $gDisableLogging\n");
        logit("Disable Output       => $gDisableOutput\n");
	    logit("Disable Error Check  => $gDisableErrorCheck\n");
	    logit("Verbose Output       => $gVerbose\n");
	    logit("Use File List        => $gExecFilelist\n");
        logit("Instance ID          => $gInstanceID\n");
        logit("Finalize Instance ID => $gFinalizeInstanceID\n");
        logit("Run Table Signal     => $gRunTable\n");
        logit("Query Band Info      => $gQueryBand\n"); # 
    	logit("Query Band Info Flag => $gPrintQueryBand\n"); # 
        logit("User Name            => $gUser\n"); # 
        logit("Job Type             => $gJobType\n\n"); # 
	}

    # Check to see if we just need to print Usage
    if ($options{h})
    {
        # Let's print usage and exit
        Usage();
        exitBlock($EXIT_OK);
    }
    
    # Set arguments passed from command line. getopts handles correctly setting @ARGV so we 
    # don't read the optional switches that were passed
    $options{fileName} = shift @ARGV; # Get fileName passed from command line

    logit("fileName is $options{fileName}\n") if $gDebug;

    # Check to make sure a fileName was passed
    unless ($options{fileName})
    {
        logit("\nInvalid FileName or Instance ID passed to " . basename($0) . "\n");
        logit("You must provide a valid ASTER file or File List\n");
        Usage();

        # Flip this to avoid processing run table in END block
        $gDisableRunTable = 1; 

        exitBlock($EXIT_BAD_FILE);
    }

    # Don't need to do any of this if we are just getting and Instance ID
    unless ($gInstanceID || $gFinalizeInstanceID)
    {
	    
	    our $iCnt = 1; # Set this to set value in hash of hash below
	    
	    # Loop through all remaining arguments (should only be Name=Value parameters from here)
	    # This will load all parameters into a Hash nested within the %options Hash (Hash of hash)
	    foreach (@ARGV)
	    {
            chomp;
	        if ($_ =~ m/^.+=.+$/)
	        {
	            $options{parameters}{$iCnt} = $_;
	        }
	        else
	        {
	            logit("\n--->Invalid Parameter passed to " . basename($0) . "\n");
	            logit(">Parameters must be specified as a name=value format.\n");
	            logit(">The Following is invalid: $_\n");
	            Usage();

                # Flip this to avoid processing run table in END block
                $gDisableRunTable = 1; 

	            exitBlock($EXIT_BAD_PARAMETERS);
	        }
	        
	        $iCnt++;
	    }
	
	    # Print out any passed parameters if Debug is on
	    if ($gDebug)
	    {
	        
	        for $iCnt (sort keys %{ $options{parameters} })
	        {
	            logit(" Parameter $iCnt => $options{parameters}{$iCnt}\n");
	        }
	    }
    }

    # Return the Options hash in case additional processing needs to take place on it
    return %options;
}

# Accepts hash as input (nested in %options from parseCommandLine)
sub loadParameters {
    # Load the parameters hash that was passed into a new hash for use within this subroutine
    my %params = %{$_[0]};

    logit("Parsing Parameters and loading into Hash...\n") if $gDebug;
    ##############################################################################################
    #Parameters can be accepted at two levels of precedence. First are the environmental variables
    #The Shell ENV variables provide the base defaults. These can be over written by any 
    #name=value parameters passed on the command line. If needed we can add a ini files to provide
    #another level of defaults, but the 2 levels are adequate and avoid overcomplication
    ##############################################################################################

    #Parameters Format has already been validated when we loaded the %options hash. Let's 
    #just set them in the %parameters hash
    
    my $iCnt = 0;
    my $iKeys; # Declare Variable (use strict is in place)
    for $iKeys (sort keys %params)
    {
        my ($name, $value) = split(/=/,$params{$iKeys}); # Split on = sign

        $parameters{$name} = $value;

        $iCnt++;

        logit(" parameters{$name} => $parameters{$name} (Should be $value)\n") if $gDebug; #Devesh Mohnani 4/29/2015
    }

    if ($gDebug)
    {
        logit("   No Parameters to Parse!\n") unless $iCnt;
    }

    return %parameters;
}


# This will generate a unique Instance ID. Similar to getSuffix but easier for
# a computer to process/store output (epoch date)
sub getInstanceID {
    logit("IID Count is $iid_count\n") if $gDebug;

    # This will pad and format the output for consitency
    my $retVal = sprintf("%010d%05d%03d",$epochtime,$pid,$iid_count);
    $iid_count++;

    return $retVal;
}

# This will return a unique file suffix. Similar to Instance ID but easier
# for a human to consume the output (YYYYMMDD_HHMMSS Date)
sub getSuffix {
    # This will pad and format the output for consitency
    return sprintf(".%4d%02d%02d_%02d%02d%02d_%05d%03d",$year,$mon,$mday,$hour,$min,$sec,$pid,$iid_count);
}

# Setup Logging
sub setupLogging {
    # Check to see if logging directory exists
    unless ( -e $RUNLOGDIR)
    {
        # Directory doesn't exist, create it with 666 permissions
        # Cannot use logit routine yet as this has to run first!!
        print "$RUNLOGDIR does not exist!\n";
        print "Creating $RUNLOGDIR\n";
        mkdir($RUNLOGDIR, 0777) or warn "Cannot create Log Dir $RUNLOGDIR: $!\n";
    }

    open(RUNLOG,">>$RUNLOGFILE") or warn "Couldn't open $RUNLOGFILE for write: $!";

    unless (flock(RUNLOG, LOCK_EX|LOCK_NB))
    {
        warn "Cannot immediately write-lock the file ($!), waiting...\n";
        unless (flock(RUNLOG, LOCK_EX))
        {
            die "Cannot get write lock on file: $!\n";
        }
    }

    # Unbuffer output or make Logfile "Hot"
    my $ofh = select RUNLOG;
    $| = 1; # Make RUNLOG socket hot
    select $ofh;

    # Flip this so we know Logging is setup
    $loggingSetup = 1;
}

# Routine for safe writing to RUNLOG handle. 
sub logit {
    my $error = shift(@_);

    chomp $error;

    # No need to do this work if logging is disabled
    unless ($gDisableLogging)
    {
        # set this for additional processing/formatting
        my $logError = $error;

        # Get rid of all newlines for logging
        $logError =~ s/\n//g;

	    my ($SEC,$MIN,$HOUR,$MDAY,$MON,$YEAR,$USEC) = CalcDateTimeHR();

        $logError = "$HOUR:$MIN:$SEC.$USEC - " . $logError;

        print RUNLOG "$logError\n";
    }

    # Want to print back to STDOUT even if $gDisableLogging
    print "$error\n" unless $gDisableOutput; 
}

# This will print the RunTable Hash back to caller using the logit routine
sub printRunTableHash {

    logit("\nRun Table Data -\n");

    for my $l1 (sort keys %RunTable)
    {
        logit("Level 1 -> $l1\n");

        for my $l2 (keys %{ $RunTable{$l1} } )
        {
            logit("   Level 2 = $l2 -> $RunTable{$l1}{$l2}\n");
        }
    } 
}

sub prepareRunTableBTEQ {

    my $RunTableScript = shift(@_);

    # Initialize a variable to store the SQL we will later print to the 
    # ASTER script file
    my $runtableSQL;

    # Set these so we can update any EndDTTM times that may be missing
    # This can happen if we processed a file list on the initial/parent node
    my ($Sec,$Min,$Hour,$Mday,$Mon,$Year,$Usec) = CalcDateTimeHR();

    # Check and see if a script was passed in, if not generate a new one
    # A script would be passed in if we encountered an error either 
    # creating a new file or trying to insert into the EDW Run Table
    unless ($RunTableScript)
    {
        $RunTableScript = "$DW_TMP/$runTablePrefix." . $RunTable{0}{IID} . '.sql';
    }

    logit("Run Table ASTER located at: $RunTableScript\n") if $gDebug;

    open(RUNTABLE, ">>$RunTableScript") or die "Could not create $RunTableScript: $!\n";  

    for my $l1 (sort keys %RunTable)
    {
        # Need to make sure we have an EndDTTM in the hash to avoid a "Invalid Timestamp" 
        # error when trying to execute the insert into the run table. This should already
        # be populated in most cases, if not let's do it now
        unless (defined $RunTable{$l1}{EndDTTM})
        {
            logit("Updating EndDTTM for RunTable node $l1 in Hash\n") if $gDebug;

            $RunTable{$l1}{EndDTTM} = "$Year-$Mon-$Mday $Hour:$Min:$Sec.$Usec";
        }

        unless (defined $RunTable{$l1}{StartDTTM})
        {
            logit("Updating StartDTTM for RunTable node $l1 in Hash\n") if $gDebug;

            $RunTable{$l1}{StartDTTM} = "$year-$mon-$mday $hour:$min:$sec.$usec";
        }

        # Need to make sure we escape or remove any chars to avoid syntax errors on insert
        $RunTable{$l1}{Args} = CheckANSISQLQuotes($RunTable{$l1}{Args});
        $RunTable{$l1}{Error} =~ s/\n//g; # Strip Newlines
        $RunTable{$l1}{Error} =~ s/\r//g; # Strip Carriage Returns
        $RunTable{$l1}{Error} =~ s/\f//g; # Strip Formfeed (you never know)
        $RunTable{$l1}{Error} =~ s/\e//g; # Strip Escape's
        $RunTable{$l1}{Error} =~ s/\t//g; # Strip Tabs
        $RunTable{$l1}{Error} =~ s/\s{2,}?//g; # Strip whitespace (must match at least 2)
        # Escape any remaining characters that will cause an insert to fail
        $RunTable{$l1}{Error} = CheckANSISQLQuotes($RunTable{$l1}{Error});

        # Now let's build the insert statement and load it to a variable
        $runtableSQL = "INSERT INTO $RUNTABLE (";
        $runtableSQL .= "parent_id";
        $runtableSQL .= ",instance_id";
        $runtableSQL .= ",sessionID"; # 
        $runtableSQL .= ",username"; # 
        $runtableSQL .= ",fileName";
        $runtableSQL .= ",status";
        $runtableSQL .= ",jobtype"; # 
        $runtableSQL .= ",args";
        $runtableSQL .= ",error_msg";
        $runtableSQL .= ",run_start_dttm";
        $runtableSQL .= ",run_end_dttm";
        $runtableSQL .= ",create_dttm";
        $runtableSQL .= ",last_update_dttm";
        $runtableSQL .= ",last_update_user";
        $runtableSQL .= ") VALUES (";
        $runtableSQL .= $RunTable{$l1}{PIID} . "";
        $runtableSQL .= "," . $RunTable{$l1}{IID} . "";
        $runtableSQL .= "," . $RunTable{$l1}{SessionID} . ""; # 
        $runtableSQL .= ",'" . $RunTable{$l1}{UserName} . "'"; # 
        $runtableSQL .= ",'" . $RunTable{$l1}{fileName} . "'";
        $runtableSQL .= ",'" . $RunTable{$l1}{Status} . "'";
        $runtableSQL .= ",'" . $RunTable{$l1}{JobType} . "'"; # 
        $runtableSQL .= ",'" . $RunTable{$l1}{Args} . "'";
        $runtableSQL .= ",'" . $RunTable{$l1}{Error} . "'";
        $runtableSQL .= ",CAST('" . $RunTable{$l1}{StartDTTM} . "'";
        $runtableSQL .= " AS TIMESTAMP(6))";
        $runtableSQL .= ",CAST('" . $RunTable{$l1}{EndDTTM} . "'"; 
        $runtableSQL .= " AS TIMESTAMP(6))";
        $runtableSQL .= ",CURRENT_TIMESTAMP(0)";
        $runtableSQL .= ",CURRENT_TIMESTAMP(0)";
        $runtableSQL .= ",USER";
        $runtableSQL .= ");\n";

        print RUNTABLE $runtableSQL;
    } 

    close(RUNTABLE);

    # Return this to caller
    return $RunTableScript;
}

sub beginInstanceID {

    my $pInstanceID = shift(@_);
    my $RunTableScript = shift(@_);

    # Initialize a variable to store the SQL we will later print to the 
    # ASTER script file
    my $runtableSQL;

    # Set these so we can update any EndDTTM times that may be missing
    # This can happen if we processed a file list on the initial/parent node
    my ($Sec,$Min,$Hour,$Mday,$Mon,$Year,$Usec) = CalcDateTimeHR();

    # Check and see if a script was passed in, if not generate a new one
    # A script would be passed in if we encountered an error either 
    # creating a new file or trying to insert into the EDW Run Table
    unless ($RunTableScript)
    {
        $RunTableScript = "$DW_TMP/$runTablePrefix." . $pInstanceID . '.sql';
    }

    #print "IID Run Table ASTER located at: $RunTableScript\n" if $gDebug;
    logit("IID Run Table ASTER located at: $RunTableScript\n") if $gDebug;

    # Need to make sure we escape any chars to avoid syntax errors on insert
    $allArgs = CheckANSISQLQuotes($allArgs);

    $runtableSQL = "INSERT INTO $RUNTABLE (";
    $runtableSQL .= " parent_id";
    $runtableSQL .= ",instance_id";
    $runtableSQL .= ",sessionid"; # 
    $runtableSQL .= ",username"; # 
    $runtableSQL .= ",fileName";
    $runtableSQL .= ",status";
    $runtableSQL .= ",jobtype"; # 
    $runtableSQL .= ",args";
    $runtableSQL .= ",run_start_dttm";
    $runtableSQL .= ",create_dttm";
    $runtableSQL .= ",last_update_dttm";
    $runtableSQL .= ",last_update_user";
    $runtableSQL .= ") VALUES (";
    $runtableSQL .= $pInstanceID . "";
    $runtableSQL .= "," . $pInstanceID . "";
    $runtableSQL .= ",SESSION"; # , SESSION is the current SessionID
    $runtableSQL .= ",USER"; # , USER is the current UserName for execASTER
    $runtableSQL .= ",'" . $options{fileName} . "'";
    $runtableSQL .= ",'R'";
    $runtableSQL .= ",'" . $gJobType . "'"; # , Inserts JobType
    $runtableSQL .= ",'" . $allArgs . "'";
    $runtableSQL .= ",CAST('$Year-$Mon-$Mday $Hour:$Min:$Sec.$Usec'";
    $runtableSQL .= " AS TIMESTAMP(6))";
    $runtableSQL .= ",CURRENT_TIMESTAMP(0)";
    $runtableSQL .= ",CURRENT_TIMESTAMP(0)";
    $runtableSQL .= ",USER";
    $runtableSQL .= ");\n";

    open(RUNTABLE, ">>$RunTableScript") or die "Could not create $RunTableScript: $!\n";  

    print RUNTABLE $runtableSQL;

    close(RUNTABLE);

    return $RunTableScript;
}

sub finalizeInstanceID {

    my $instanceID = shift(@_);
    my $RunTableScript = shift(@_);

    # Initialize a variable to store the SQL we will later print to the 
    # ASTER script file
    my $runtableSQL;

    # Set these so we can update any EndDTTM times that may be missing
    # This can happen if we processed a file list on the initial/parent node
    my ($Sec,$Min,$Hour,$Mday,$Mon,$Year,$Usec) = CalcDateTimeHR();

    # Check and see if a script was passed in, if not generate a new one
    # A script would be passed in if we encountered an error either 
    # creating a new file or trying to insert into the EDW Run Table
    unless ($RunTableScript)
    {
        $RunTableScript = "$DW_TMP/$runTablePrefix." . $instanceID . 'F.sql';
    }

    logit("Finalize IID Run Table ASTER located at: $RunTableScript\n") if $gDebug;

    $runtableSQL = "UPDATE $RUNTABLE ";
    $runtableSQL .= "SET ";
    $runtableSQL .= "run_end_dttm = ";
    $runtableSQL .= "CAST('$Year-$Mon-$Mday $Hour:$Min:$Sec.$Usec'";
    $runtableSQL .= " AS TIMESTAMP(6))";
    $runtableSQL .= ",status = CASE WHEN STATUS = 'R' THEN 'C' ELSE 'E' END";
    $runtableSQL .= ",last_update_dttm = CURRENT_TIMESTAMP(0)";
    $runtableSQL .= ",last_update_user = USER";
    $runtableSQL .= " WHERE ";
    $runtableSQL .= "instance_id = $instanceID;";

    open(RUNTABLE, ">>$RunTableScript") or die "Could not create $RunTableScript: $!\n";  

    print RUNTABLE $runtableSQL;

    close(RUNTABLE);

    return $RunTableScript;
}

# This will replace all variables in ASTER scripts with paramater values or environment
# variable values. 
sub makeInstanceScript {
    # Let's read in the ASTER script and suffix
    my ($sql_script, $suffix) = @_;

    logit("Preparing to Build Instance Script for: $sql_script\n") if $gDebug;

    # Now we need to build the variable for the instance file
    my $instanceScript = "$DW_TMP/" . basename($sql_script) . $suffix . '.tmp';

    # Lets attempt to open up all the files before we start processing anything 
    # further in case there are errors (will die on error)
    open(SQLSCRIPT, "<$sql_script") or die "Could not open $sql_script for read: $!\n";
    open(INSTANCESCRIPT, ">$instanceScript") or die "Could not open $instanceScript for write: $!\n";

    my $inComment = 0;
    #---------------------------------------------------------------------------    
    foreach (<SQLSCRIPT>)
    {
        chomp; # Need to chomp the line to avoid any potentioal issues with the regex

        my $Line = $_;

        my $foundComment = 0;

        # Check and see if the current line has any variables to be replaced. 
        # Variables will begin with a $ (Dollar) sign, Loop through the line
        # until all variables are replaced or handled
        MATCH:
        
        #---------------------------------------------------------------------
        while ($Line =~ m/\$(\w+)/i)
        #---------------------------------------------------------------------
        {
            # Assign the first varible found to $match 
            # $1 will be set to the text after the $ from the last regex
            my $match = $1;

            # We want to check and see if we have a comment string.
            # This regex should match a $ anywhere before the -- comment (basically we want to 
            # do work before we encounter the comment if true/match)
            unless ($Line =~ m/\$.*?--/)
            {
                # We did not have a variable before the comment
                # This regex should match a -- followed by a $ anywhere after the comment
	            if ($Line =~ m/--.*?\$/)
	            {
	                logit("INLINE Comment encountered: '$Line'\n\n") if $gDebug; 

	                $foundComment = 1;
	            }
            }  

            # This will check and see if we have the other type of comment string
            # This regex will match a $ anywhere before the /* Comment
            unless ($Line =~ m/\$.*?\/\*/)
            {
                # We did not have a variable before the comment
                # This regex will match anything after the /* comment
	            if ($Line =~ m/\/\*.*?/)
	            {
	                logit("MULTILINE Comment encountered: '$Line'\n\n") if $gDebug; 

	                $foundComment = 1;
	                $inComment = 1;
	            }
            }

            # We have a Variable in this line, let's process
            # We want the parameters passed at runtime (command line) to take 
            # precidince over ENV variables, so if they match, use it otherwise try and match the ENV ones
            if (exists $parameters{$match})
            {
                logit("Found Parameters Variable in: $Line\n") if $gVerbose;
                $Line =~ s/\$(\w+)/$parameters{$match}/i; 
            }
            elsif (exists $ENV{$match})
            {
                logit("Found ENV Variable in: $Line\n") if $gVerbose;
                $Line =~ s/\$(\w+)/$ENV{$match}/i; 
            }
            else
            {
                unless ($inComment)
                {
	                logit("!!! PARAMETER NOT FOUND - Unable to subsitute runtime variable \$$match\n\n");
                    # Couldn't replace the variable, need to just exit the loop now (this will error
                    # once submited to teradata)
                    $Line =~ s/\$(\w+)/($1-VARIABLE NOT FOUND!)/; 
                    next MATCH;

                    # If we'd rather exit then send to Teradata uncomment below
                    # Flip this to avoid processing run table in END block
                    #$gDisableRunTable = 1; 
                    #exitBlock($EXIT_BAD_PARAMETERS);
                }
                else
                {
                    # We are in a comment, lets indicate we could not find a match
                    $Line =~ s/\$(\w+)/($1-VARIABLE NOT FOUND!)/; 
                }
            }
            
            logit("^^After Variable Substitution: $Line\n\n") if $gVerbose;
        #---------------------------------------------------------------------
        } # End While
        #---------------------------------------------------------------------

        if ($inComment)
        {
            # Check and see if we have the end multiline (C Style) comment
            unless ($Line =~ m/\$.*?\*\//)
            {
                $inComment = 0;
            }
        }

        # Now let's print the resulting line with substitutions to the instance file
        print INSTANCESCRIPT "$Line\n"; # Need to add the newline since we chomped it earlier
    }

    # Let's clean up all the open file handles

    close(SQLSCRIPT);
    close(INSTANCESCRIPT);

    # Let's return the instanceScript variable now that it contains data
    return $instanceScript;
}

sub makeCommandFile {
    # Let's read in the instanceScript and suffix
    my ($instanceScript, $suffix) = @_;

    logit("Preparing Command File for $instanceScript\n") if $gDebug;

    # Now let's build the variable for the Command file
    my $cmdFile = "$DW_TMP/" . getFileRoot($instanceScript) . $suffix . '.cmd'; 

    # Let's attempt to open up the command file for write before we proceed
    # cause it's all for nothing if we can't open the file for writing
    open(COMMANDFILE, ">$cmdFile") or die "Could not open $cmdFile for write: $!\n";

    # Now we have our file open, Let's go get the Credentials
    my $credentials;
    if (exists $parameters{CRED})
    {
        # Looks like credentials were passed on command line, let's use them
        $credentials = $parameters{CRED};
    }
    else
    {
        # , See if specific user was requested at runtime
        if ($gUser)
        {
            logit("\nCredentials requested for $gUser\n") if $gDebug;

            # Go get credentials searching on Username
            $credentials = getAsterCredentialsByUser($gUser);
        }
        else
        {
            # Credentials were not provided. Let's go get them using the script name
            # This is a pretty resource intensive operation - Most likey could be optimized
            $credentials = getAsterCredentials(basename($instanceScript));
        }
    }

    # Don't want to call logit here to avoid printing credentials to log files but do want
    # to be able to print them back to screen in case we are having problems
    print "   Got Credentials: $credentials\n" if $gDebug;

    # Extract Username From Credentials 
    if ($credentials =~ m/\/(.*)\,/)
    {
        # Username should be between forward slash (/) and comma (,) and be assigned to $1 if matched
        # in above regex
        $gUserName = $1;

        logit("\nGot User Name '$gUserName'\n") if $gDebug;
    }
    else
    {
        # Unable to match regex, use a default value since it's informational only
        $gUserName = 'UNKNOWN';

        logit("Failed to extract User Name from Credentials...\n");
    	exitBlock($EXIT_OTHER_ERROR);
    }

    # Build and validate Query Band info, 
    my $QueryBand = getQueryBand($gQueryBand);
    logit("QUERY_BAND => $QueryBand\n\n") if $gDebug || $gPrintQueryBand;

    # Print statements to Command File
    print COMMANDFILE "\.LOGON $credentials;\n";
    print COMMANDFILE "SELECT SESSION;\n"; # , Used to get SessionId for Run Table
    print COMMANDFILE "\.SET WIDTH 240;\n";

    # Add Query Band info to ASTER jobs, 
    ### NOTE: If Query Band info is set directly in ASTER script it will overwrite settings here
    if ($QueryBand)
    {
        print COMMANDFILE "SET QUERY_BAND = '" . $QueryBand . "' FOR SESSION;\n"; 
    }

    print COMMANDFILE "\.RUN FILE=$instanceScript;\n";
    print COMMANDFILE "\.EXIT ERRORCODE\n";

    close(COMMANDFILE);

    return $cmdFile;
}

sub getQueryBand {
    my $queryband = shift;

    # Declare a few variables we'll use later
    my $QB; # Used as return variable

    # Build default Query Band
    # Query Bands use Name=Value pairs delimited by a semi colon (;)
    $QB = "APPLICATION=execASTER;";
    $QB .= "SCRIPT=" . $options{fileName} . ";";
    $QB .= "USERNAME=" . $gUserName . ";";

    # Validate Query Band info passed from command line
    if ($queryband)
    {
        # Split on semi Colon (;)
        my @QB = split(/;/,$queryband);
        foreach (@QB)
        {
           if ($_ =~ m/.*\=.*/)
           {
              $QB .= $_ . ";";
           }
           else
           {
              logit("Invalid Query Band String, Discarding $_\n");
           }
        }
    }
    else
    {    
       logit("\nNo Supplemental Query Band String Provided...\n\n") if $gDebug;
    }

    # Return formatted Query Band to caller
    return $QB;
}

sub checkForASTERErrors {
    my $logfile = shift;

    logit("Starting to Parse Log for Errors...\n") if $gDebug;

    # Declare a few variables we'll use later
    my $errMsg; # Used as return variable
    my @LOG; # Used like FH to Tie file to for reading

    # We are going to use Tie so we can access the $logfile like an array without
    # actaully slurping it into memory
    tie @LOG, 'Tie::File', $logfile, mode => O_RDONLY 
        or die "Cannot tie $logfile: $!\n";

    # Get the last line of the $logfile 
     # Flip this to indicate errors were encountered
    # Unless we are processing run table as it has it's own built in logic 
    # for handling errors.
    $gASTERErrors = 1 unless $gRunTable;

    # Initilize a few more variables
    my $iPos = 0;
    my $Found = 0;
    my $startPos = 0;
    my $endPos = 0;
    $errMsg = '';
    # Now we are going to parse through the logfile and find the error so we 
    # can return a snippet
    # We already have the logfile tied to an array, so let's just loop the array
    foreach (@LOG)
    {
        chomp;

        # let's get the line into a readable variable
         my $line = $_;

         # Check and see if line = ERROR
         if ($line =~ m/ERROR: /i)
         {
             $Found++;
             $gASTERErrors = 1;
             $errMsg .= $LOG[$startPos] . "\n";
         }

         # Increment $iPos so we know what Array element we are on
         # Remember File is Tied to array we are looping!!
         $startPos++;
    }
    $gASTERErrors =0 if (!$Found);
    $errMsg = 0 if ($errMsg eq '');
    logit("Finished Parsing Log for errors.\n") if $gDebug;

    # Now let's return $errMsg. Will be zero if there was no error
    return $errMsg;
}

sub extractSessionID {
    my $logfile = shift;

    logit("Starting to Parse Log for SessionID...\n") if $gDebug;

    # Declare a few variables we'll use later
    my $SessionID; # Used as return variable
    my @LOG; # Used like FH to Tie file to for reading

    # We are going to use Tie so we can access the $logfile like an array without
    # actaully slurping it into memory
    tie @LOG, 'Tie::File', $logfile, mode => O_RDONLY 
        or die "Cannot tie $logfile: $!\n";


    # Initilize a few more variables
    my $iPos = 0;
    my $Found = 0;
    my $startPos = 0;
    my $endPos = 0;

    # Now we are going to parse through the logfile and find the session ID so we 
    # can return to caller
    # We already have the logfile tied to an array, so let's just loop the array
    foreach (@LOG)
    {
        chomp;

        # let's get the line into a readable variable
         my $line = $_;

         # Check for SELECT SESSION;
         if ($line =~ m/SELECT\ SESSION\;/
                 and !$Found)
         {
             $startPos = $iPos + 7;
             $Found++;
         }

         $endPos = $startPos;

         # Increment $iPos so we know what Array element we are on
         # Remember File is Tied to array we are looping!!
         $iPos++;
    }

    # Let's extract the session id and return it
    # This will append the logfile line onto $SessionID for each line up to $endPos
    # This is overkill for what were doing, but provides flexability if ASTER log output changes
    while ($startPos <= $endPos)
    {
        $SessionID .= $LOG[$startPos] . "\n";
        $startPos++
    }

    # Perform a TRIM on SessionID
    $SessionID =~ s/^\s+//;
    $SessionID =~ s/\s+$//;

    # Check to see if we got the Session ID or not (Failure to connect will result in this getting set incorrectly)
    if ($SessionID =~ m/^\+\-\-/)
    {
        # Did not get SessionID, Let's send a warning and set it to 0. This is NOT a critical error!
        # Sending warning here causes MAJOR issues in Control-M, Disabling the warning unless in Debug...
        logit("Unable to Parse SessionID from Log!\n") if $gDebug;
        $SessionID = 0;
    }
    else
    {
        logit("Finished Parsing Log for SessionID.\n") if $gDebug;
    }


    # Now let's return $SessionID.
    return $SessionID;
}

sub processRunTableHash {

    my $rc;

    # We may want to fork() here in the future to have this handle 
    # all run table updates in another process, this will incur additonal
    # overhead on the linux system, but would allow this program to return
    # faster and speed up overall flow

    # Let's go prepare the RunTable SQL. This will go and generate another
    # ASTER script that we will then execute with this same program, but
    # we will disable any further writes to the run table (to avoid an 
    # infinite loop) by using the -r option (-r will enable -z)
    my $RunTableScript = prepareRunTableBTEQ();

    # Let's go execute the script we have just prepared
    processRunTable($RunTableScript);
}

sub processRunTable {

    my $RunTableScript = shift(@_);
    my $rc;

    # This is a counter so we know how many times we have looped below
    my $iRetries = 1;

    # This implements some retry logic for the Run Table
    LOOP: 
    { 
	    do
	    {
            logit("\n---> Preparing to write to Run Table.\n") if $gVerbose;

	        # Now let's go execute the new ASTER and insert the records into the runtable
            # Need to make sure we pass along appropriate options 
            if ($gPersistentFiles)
            {
	            #system("$perl $DW_BIN/execBTEQ.pl -rp $RunTableScript");
            }
            else
            {
	            #system("$perl $DW_BIN/execBTEQ.pl -r $RunTableScript");
            }
	
	        # Let's check and see if it failed or not
	        if ($? > 0)
	        {
	            # Looks like the Run Table insert failed
	            # Get actual Return Code from last call
	            $rc = ($? / 256); 
	
	            logit("System Call to -r returned: $rc ($?)\n") if $gDebug;

                if ($gVerbose)
                {
	                logit("Failed to write to $RUNTABLE: $rc\n") if $gVerbose;
                    logit("Will retry in " . $iRetries**2 . " Seconds " 
                        . ($RetryCnt - $iRetries) . " more times.\n");
                }
	
	            # Insert into run table failed - let's flag for write to queue 
	            # Flip this bit to trigger exitBlock and END block actions
	            $gRunTableErrors = 1; 
	
	            # Let's go to sleep before we retry.
	            # This will increase the sleep time with each failure
	            # 1, 4, 9, 15 Seconds, etc... (1^2,2^2,3^2,4^2)
	            sleep ($iRetries**2); 
	        }
	        else
	        {
	            # No errors encountered, Let's exit the loop
                logit("\n---> Succesfully wrote to Run Table.\n") if $gVerbose;

	            $gRunTableErrors = 0; 
	            last;
	        }
	
	        $iRetries++;
	
	    } while ($iRetries <= $RetryCnt);
    }
}

# This is the single exit point of the script
sub exitBlock {
    my $exitErr = shift(@_);
    cleanuptemp();

    logit("EXITING WITH CODE: " . $exitErr . "\n") if $gVerbose;

    unless ($gDisableRunTable || $gRunTable || $gShowHelp)
    {
        processRunTableHash();
    }

    # This will be set if we had errors writing to Run table, but not necessarily 
    # executing a ASTER
    if ($gRunTableErrors)
    {
        if ($gInstanceID)
        {
            my $RunTableScript = beginInstanceID($instanceID,$RunTableFile);
        }
        else
        {
            my $RunTableScript = prepareRunTableBTEQ($RunTableFile);
        }
    }
    #print "11: Exit: $exitErr,$globalRV; \n";
    $globalRV =$globalRV >> 8;
    if ($globalRV != -9999 && $globalRV !=0)
    {
      #print "12: Exit: $globalRV; \n";
      exit $globalRV;
    }
    else
    {
      #print "13: Exit: $exitErr,$globalRV; \n";
      exit $exitErr;
    }
}

sub cleanuptemp()
{
    # Clean up open filehandles
    unless ($gDisableLogging)
    {
        close(RUNLOG);
        $loggingSetup = 0;
    }
    # DELETE the $RUNLOGFILE file if it's zero bytes
    # This will get created even if $gDisableLogging was requested by -l
    unlink($RUNLOGFILE) if (-z $RUNLOGFILE);

    unlink($tmpinsfile);
    unlink($tmplogfile);
    #print "2: Exit: $globalRV; \n";
    #exit $globalRV;
}    

# This is executed at the end regaurdless of how it exits
#END {
#
#}

