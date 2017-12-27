$x='VID_20160221_151733.mp4';




$x =~ s/vid_([0-9]{8})_(.*)$/$1/i;

print "\n$x\n";

@chars=split('',$x);

$yyyy=join('',@chars[0..3]);
$mm=join('',@chars[4,5]);

$folder_name=$yyyy."_".$mm;
print "\n$folder_name\n";
