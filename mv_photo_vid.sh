#!/bin/bash +x 
##################################################################
#Script to make duplicate copy of designated Earth folder 
##################################################################
echo1() { flag=''; msg=''; msg="$1";
if   [ "$msg" == '-n' ]; then msg=$2; echo -n "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;
elif [ "$msg" == '-t' ]; then msg=$2; echo "$msg"|tee -a $L; else echo "{`date +%Y%m%d:%H%M%S`} $msg"|tee -a $L;fi }
############################################################
set -o pipefail
# Prepare Log name
L=$HOME/log/`basename ${0}`_`date +%Y%m%d_%H%M`.log
echo1 "Starting Nexus Photo Move and backup";echo1 "Log: $L"
##################### EARTH / URANUS SECTION ##################
# 1A. ping check earth/uranus (Primary Source/Target)
echo1 "Pinging VENUS & URANUS"; 
ping -c 1 192.168.1.23 >> $L 2>&1; RV1=$?; ping -c 1 192.168.1.29 >> $L 2>&1; RV2=$?
if [ $RV1 != "0" -o $RV2 != "0" ]; then
   echo1 "Ping Failed: EARTH = $RV1  URANUS = $RV2"; echo1 "exiting 1"; exit 1
else
   ############################################################
   # 1B. Mount Check earth/uranus (Primary Source/Target)
   echo1 "Both Earth and Uranus are pingable ; Proceeding to Mount both"
   $HOME/bin/1x_mnt_earth.sh  -M >> $L 2>&1; RV1=$?; $HOME/bin/1x_mnt_uranus.sh -M >> $L 2>&1; RV2=$?
   if [ $RV1 != 0 -o $RV2 != "0" ]; then
      echo1 "Mount Failed: EARTH = $RV1  URANUS = $RV2"; echo1 "exiting 1"
      SUB="Backup_did_not_start_at_`date +%Y%m%d_%T`" ; $HOME/bin/sm.sh 'dmohnani1@gmail.com' "$SUB" $L; exit 1
   fi
fi
##################### PLUTO SECTION ###########################
# 2A. ping Check PLUTO (Backup Paths)
RV1=0
ping -c 1 192.168.1.28 >> $L 2>&1; RV2=$?
if [ $RV1 != "0" -o $RV2 != "0" ]; then
   echo1 "Ping Failed: PLUTO = $RV2" ; echo1 "exiting 1" ; exit 1
else
   ############################################################
   # 2B. Mount Check PLUTO
   echo1 "PLUTO are pingable ; Proceeding to Mount "
   ### $HOME/bin/1x_mnt_mars.sh  -M >> $L 2>&1; RV1=$?; 
   $HOME/bin/1x_mnt_pluto.sh -M >> $L 2>&1; RV2=$?
   if [ $RV1 != 0 -o $RV2 != "0" ]; then
      echo1 "Mount Failed: PLUTO = $RV2"; echo1 "exiting 1"; SUB="Backup_did_not_start_at_`date +%Y%m%d_%T`"
      $HOME/bin/sm.sh 'dmohnani1@gmail.com' "$SUB" $L; exit 1
   fi
fi
############### 3. URANUS TO EARTH SYNC PHOTO & VID############
echo1 "Running mv_photos.pl $DNEX $PLIB 0 1"; $HOME/bin/mv_photos.pl $DNEX $PLIB 0 1 >> $L 2>&1 ; RV1=$?
echo1 "Running mv_photos.pl $PNEX $PLIB 0 1"; $HOME/bin/mv_photos.pl $PNEX $PLIB 0 1 >> $L 2>&1 ; RV2=$?

echo1 "Running mv_videos.pl $DNEX $PLIB"    ; $HOME/bin/mv_videos.pl $DNEX $PLIB     >> $L 2>&1 ; RV3=$?
echo1 "Running mv_videos.pl $PNEX $PLIB"    ; $HOME/bin/mv_videos.pl $PNEX $PLIB     >> $L 2>&1 ; RV4=$?

if [ $RV1 == "0" -a  $RV3 == "0" ];then mv $DNEX/* $DNEX/../D_copy_done/ ; fi
if [ $RV2 == "0" -a  $RV4 == "0" ];then mv $PNEX/* $PNEX/../P_copy_done/ ; fi

echo "Moving Dupes to $DUPP" >>$L 2>&1
for i in `find $PLIB -name *_[0-9][0-9].jpg`; do mv $i $DUPP ; done
for i in `find $VLIB -name *_[0-9][0-9].mp4`; do mv $i $DUPP ; done
SUB="Ph_Vid_Move_completed_at_`date +%Y%m%d_%T`" ; $HOME/bin/sm.sh 'dmohnanis@gmail.com' "$SUB" empty

############# 4. CREATE BACKUP COPY OF EARTH LIBRARY #######
# 4A. NORMALIZE DOCS
if [ X$NORM == X1 ];then $HOME/bin/norm.sh /media1/mnt/doc 7 1 0 0 1 >> $L 2>&1; fi
echo1 "/media1/mnt = earth/doc"
echo1 "/media2/mnt = campics_n_earthpublic"
echo1 "/media3     = pogoplug_uranus"
env|grep media|sort |tee -a $L

# 4B. Documents backup
$HOME/bin/make_folder_backup.sh /media1/mnt/doc /media5/mnt_sda1/earth_backup_pluto/ $L 2>&1
if [ $? != 0 ];then SUB="Failed  /media1/mnt/doc /media5/mnt_sda1/earth_backup_pluto/"; $HOME/bin/sm.sh 'dmohnani1@gmail.com' "$SUB" empty; exit 1; fi

# 4C. Photo backup
#$HOME/bin/make_folder_backup.sh $PLIB /media5/mnt_sda1/earth_backup_pluto/_0_PHOTO_VIDEO_Library $L 2>&1
#if [ $? != 0 ];then SUB="Failed $PLIB /media5/mnt_sda1/earth_backup_pluto/"; $HOME/bin/sm.sh 'dmohnani1@gmail.com' "$SUB" empty; exit 1; fi;
# all done
SUB="Doc_PLIB_replicated_to_Pluto_at_`date +%Y%m%d_%T`"
$HOME/bin/sm.sh 'dmohnanis@gmail.com' "$SUB" empty
echo1 "Log: $L"
###########################################################
