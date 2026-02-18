#!/bin/bash
# This program takes 3 parameters and 
#   copies all files/folders under
#   $1      S     Source Folder     #e.g. EARTH Mount -> S='/media1/mnt/doc'           # to 
#   $2      T     Target Folder     #     MARS Mount  -> T='/media4/earth_backup/'doc' # which changed in last
#   $3      E     Excluded Ones
################################
# Source Path and underneath directories must be normalized
################################
# Source Path and underneath Filenames/filenames must be Normalized already.
#  EARTH/DOC      on /media1/mnt/doc
#  EARTH/PUBLIC   on /media2/mnt/earthpublic
#  URANUS/URANUS/ on /media3
#  MARS/Public    on /media4
#  PLUTO/PLUTO    on /media5
################################
echo1() {
 flag=''; msg=''; msg="$1"; 
if   [ "$msg" == '-n' ]; then msg=$2; echo -n "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;
elif [ "$msg" == '-t' ]; then msg=$2; echo "$msg"|tee -a $L; else echo "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;fi
}
usage() {
 echo "Usage:
   `basename $0` <Source> <Target> [<exclusion>]"
}
################################
#Begin Validation
S=$1 ; T=$2 ; H=$3 ; 
L=$HOME/log/`basename $0`.`date +%Y%m%d_%H%M%S`.log;echo1 -t $L; touch $L 
if [ X$S == X -o X$T == X ];then  echo1 "Blank S or T; please recheck paths" ; echo1 "Exiting 1"; usage; exit 1  ;fi
if [ ! -d $S -o ! -d $T ];then echo1 "Invalid dir $S or $T - please recheck paths"; echo1 "Exiting 2"; usage; exit 2 ;fi
################################
#Validation complete continue
echo1 "S=$S";echo1 "T=$T"; echo1 "L=$L"
b=`basename $S`
#export RP=echo $S sed s/\//\\\\\//g'    #Regex-Escape Path
#echo1 "Source Base=$b Source regex-escaped Path=$RP" 
#find only changed files/dir in last $H minutes ; and copy to destination
#for i in `find $S $str -type f` ;do
#    j=`echo $i|perl -pe 's/$ENV{RP}//g'`
#    d=`dirname $j`
#if [ ! -d $T/$b/$d ]; then
    if [ ! -d $T/$b ]; then
       mkdir -p $T/$b   
    fi
#    echo1 "cp -pf $S/$j $T/$b/$j"
#    cp -pf "$S/$j" "$T/$b/$j"
rsync -arvR -A -X $S $T/$b --log-file=$L
    RV=$?
    if [ $RV -eq 0 ]; then MS=CPASS ; else MS=CFAIL ; fi
#done
echo $RV
L1=`basename $L`
echo "<HTML><TABLE BORDER=2>" > /tmp/$L1
sed -e 's/^/<TR><TD>/g' $L|sed -e 's/$/<\/TD><\/TR>/g' >> /tmp/$L1
echo "</TABLE></HTML>" >> /tmp/$L1
$HOME/bin/sm.sh 'xyzz@yahoo.com' "${MS}_Backup" /tmp/$L1

rm /tmp/$L1

find $HOME/log/ -name folder_rsync'*'  -mtime +2 -exec rm -f {} \;
