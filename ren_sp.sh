pd=`pwd`

if [ $# -eq "0" ];
  echo "No Param Passed: Usage = `basename $0` <Path>"
  exit 1
fi

if [ ! -d $1 ];then
  echo "$1 is not a valid Directory"
  exit 1
fi

cd $1
if [ $? -ne "0" ];then
 echo "Failed to cd $1"
 exit 1
done

for i in `ls -lart|tr -s ' '|cut -d ' ' -f 9-200|egrep -v '^\.'|tr ' ' '_'|tr '~' '_'|tr '-' '_'|tr -s '_'`
do 
    j="`echo $i|tr '_' ' '|tr '~' '_'|tr '-' '_'|tr -s '_'`"
    if [ "$i" -ne "$j" ]; then
       mv "$j" "$i"
       if [ $? -ne "0" ];then
           echo "Failed to mv "
           exit 1
       done
    fi
done
cd $pd
