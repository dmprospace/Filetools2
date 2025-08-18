#!/bin/bash +x 
##################################################################
#Script to -sync Photos, -then make duplicate copy of certain designated Earth foldes
##################################################################
echo1() { flag=''; msg=''; msg="$1";
if   [ "$msg" == '-n' ]; then msg=$2; echo -n "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;
elif [ "$msg" == '-t' ]; then msg=$2; echo "$msg"|tee -a $L; else echo "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;fi }
############################################################
S=$1; T=$2; NORM=$3
############################################################
set -o pipefail
# Prepare Log name
L=$HOME/log/`basename $0`_`date +%Y%m%d_%H%M`.log
echo1 "Starting backup"
############################################################
# 1A. ping check earth/uranus (Primary Source/Target)
echo1 "Pinging EARTH & URANUS"; 
ping -c 1 192.168.1.24 >> $L 2>&1; RV1=$?; ping -c 1 192.168.1.29 >> $L 2>&1; RV2=$?
if [ $RV1 != "0" -o $RV2 != "0" ]; then
   echo1 "Ping Failed: EARTH = $RV1  URANUS = $RV2"
   echo1 "exiting 1"
   exit 1
else
   ############################################################
   # 1B. Mount Check earth/uranus (Primary Source/Target)
   echo1 "Both Earth and Uranus are pingable ; Proceeding to Mount both"
   $HOME/bin/1x_mnt_earth.sh  -M >> $L 2>&1; RV1=$?; $HOME/bin/1x_mnt_uranus.sh -M >> $L 2>&1; RV2=$?
   if [ $RV1 != 0 -o $RV2 != "0" ]; then
      echo1 "Mount Failed: EARTH = $RV1  URANUS = $RV2"
      echo1 "exiting 1"
      SUB="Backup_did_not_start_at_`date +%Y%m%d_%T`"
      $HOME/bin/sm.sh 'EMAIL' "$SUB" $L
      exit 1
   fi
fi
############################################################
# 2A. ping Check MARS/PLUTO (Backup Paths)
ping -c 1 192.168.1.25 >> $L 2>&1; RV1=$?; ping -c 1 192.168.1.28 >> $L 2>&1; RV2=$?
if [ $RV1 != "0" -o $RV2 != "0" ]; then
   echo1 "Ping Failed: MARS = $RV1  PLUTO = $RV2"
   echo1 "exiting 1"
   exit 1
else
   ############################################################
   # 2B. Mount Check MARS/PLUTO
   echo1 "Both MARS and PLUTO are pingable ; Proceeding to Mount both"
   $HOME/bin/1x_mnt_mars.sh  -M >> $L 2>&1; RV1=$?; $HOME/bin/1x_mnt_pluto.sh -M >> $L 2>&1; RV2=$?
   if [ $RV1 != 0 -o $RV2 != "0" ]; then
      echo1 "Mount Failed: MARS = $RV1  PLUTO = $RV2"
      echo1 "exiting 1"
      SUB="Backup_did_not_start_at_`date +%Y%m%d_%T`"
      $HOME/bin/sm.sh 'EMAIL' "$SUB" $L
      exit 1
   fi
fi
exit 0
############################################################
# 2A. Normalize docs
if [ X$NORM == X1 ];then $HOME/bin/norm.sh /media1/mnt/doc 7 1 0 0 1 >> $L 2>&1; fi
echo1 "/media1/mnt = earth/doc"
echo1 "/media2/mnt = campics_n_earthpublic"
echo1 "/media3     = pogoplug_uranus"
env|grep media|sort |tee -a $L
# Documents backup
$HOME/bin/make_folder_backup.sh /media1/mnt/doc /media4/earth_backup $L 2>&1
if [ $? != 0 ];then SUB="Failed  /media1/mnt/doc /media4/earth_backup"; $HOME/bin/sm.sh 'EMAIL' "$SUB" empty; exit 1; fi
# Photo backup
#$HOME/bin/make_folder_backup.sh $PLIB /media4/earth_backup/_0_PHOTO_VIDEO_Library $L 2>&1
if [ $? != 0 ];then SUB="Failed  $PLIB /media4/earth_backup/_0_PHOTO_VIDEO_Library"; $HOME/bin/sm.sh 'EMAIL' "$SUB" empty; exit 1; fi;
SUB="Doc_PLIB_replicated_to_Mars_at_`date +%Y%m%d_%T`"
$HOME/bin/sm.sh 'EMAIL' "$SUB" empty
############################################################
