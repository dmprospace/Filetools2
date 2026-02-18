#!/bin/bash

NORM=$1
set -o pipefail
L=~/log/`basename $0`_`date +%Y%m%d_%H%M.log
echo "Starting backup at `date +%D_%T`" >$L 2>&1
echo "checking EARTH" |tee -a $L
ping -c 1 192.168.1.24 >> $L 2>&1
RV1=$?
ping -c 1 192.168.1.29 >> $L 2>&1
RV2=$?
if [ $RV1 -eq "0" -a $RV2 -eq "0" ]; then
  echo "Both Earth and Uranus are pingable ; Proceeding to mount check"|tee -a $L
~/bin/1x_mnt_earth.sh -M >> $L 2>&1
RV1=$?
~/bin/1x_mnt_uranus.sh -M >> $L 2>&1
RV2=$?

echo "
/media1: mnt  is_earth_doc
/media2: mnt  is_campics_n_earthpublic
/media3:  -   is_pogoplug_uranus
"
env|grep media|sort

else
  echo "Earth and/or Urnaus are unavailable ; Exiting Photo backup" |tee -a $L
  SUB="Backup_did_not_start_at_`date +%Y%m%d_%T`"
  ~/bin/sm.sh 'xyzz@gmail.com' "$SUB" empty
  exit 1
fi
 

echo "Running ~/bin/mv_photos.pl $DNEX $PLIB 0 1" >>$L 2>&1
~/bin/mv_photos.pl $DNEX $PLIB 0 1 >> $L 2>&1
echo "Running ~/bin/mv_photos.pl $PNEX $PLIB 0 1"  >>$L 2>&1
~/bin/mv_photos.pl $PNEX $PLIB 0 1 >> $L 2>&1
echo "Running ~/bin/mv_videos.pl $DNEX $PLIB"  >>$L 2>&1
~/bin/mv_videos.pl $DNEX $PLIB     >> $L 2>&1  >>$L 2>&1
echo "Running ~/bin/mv_videos.pl $PNEX $PLIB"  >>$L 2>&1
~/bin/mv_videos.pl $PNEX $PLIB     >> $L 2>&1

echo "Moving Dupes to $DUPP" >>$L 2>&1
for i in `find $PLIB -name *_[0-9][0-9].jpg`; do mv $i $DUPP ; done
for i in `find $VLIB -name *_[0-9][0-9].mp4`; do mv $i $DUPP ; done
SUB="Ph_Vid_Backup_completed_at_`date +%Y%m%d_%T`"
~/bin/sm.sh 'xyzz@gmail.com' "$SUB" empty
