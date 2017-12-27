#!/bin/bash 

param=$1
depthlim=$2
nfalso=$3
namelength=$4
justpreview=$5
full_normz=$6

echo "-----------------------------------------------------------------------------------------------------------"
echo "param=$1"
echo "depthlim=$2"
echo "nfalso=$3"
echo "namelength=$4"
echo "justpreview=$5"
echo "full_normz=$6"
echo "-----------------------------------------------------------------------------------------------------------"

if [ X"$justpreview" == X ];then
  justpreview=0
fi
if [ X"$nfalso" == X ];then
  nfalso=0
fi
if [ X"$namelength" == X ];then
  namelength=0
fi
if [ X"$full_normz" == X ];then
  full_normz=0
fi

start=0
depthlist="$start"

##################################
if [ "X$param" != "X" ]
then
  echo "Normalizing names of all dirs and subdirs in Path $param"
else
 echo "($param) is not a directory"
 echo "This Script Normalizes names of all dirs , subdirs (& files) in the Path $param"
 echo "Usage: `basename $0` <dirpath> <depthlimt> [<normalize_files_too>] [nmlength] [preview] [Full_Normalize]"
         echo "                (1)        (2)               (3)               (4)       (5)          (6)"
  exit 1
fi

################################
while [ $start -lt $depthlim ]
do
  tmp=`expr $start + 1`
  depthlist="$depthlist $tmp"
  start=$tmp
done
echo $depthlist
################################
echo "Normalizing all directories in Path $param upto depth $depthlim"
for maxdepth in $depthlist
do
  for i in `find $param -maxdepth $maxdepth -type d`
  do
   #ndf.pl        <nd|nf> <Path> <mailflag> <namelength> <previewflag>
   if [ "$justpreview" -eq "1" ];then
     $HOME/bin/ndf.pl nd "$i" 0 $namelength 1 $full_normz
   else
    $HOME/bin/ndf.pl nd "$i" 0 $namelength 0 $full_normz
   fi
  done
done

################################
if [ X"$nfalso" == X"1" ];then
  echo "#########################################"
  echo " "
  echo "Normalizing all files in Path $param and its sub-directories"
  echo " "
  echo "#########################################"
  maxdepth=$depthlim

  for j in `find $param -maxdepth $maxdepth -type d`
  do
   if [ X"$justpreview" == X"1" ];then
     $HOME/bin/ndf.pl nf "$j" 0 $namelength 1 $full_normz
   else
     $HOME/bin/ndf.pl nf "$j" 0 $namelength 0 $full_normz
   fi
  done
fi
