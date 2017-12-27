use strict;
use warnings;

my $s4='99:30:30';
my $s5='00:50:30';

my $x=add_time($s4,$s5);
print "\nT=$x\n";


sub add_time
{
  my $t1=shift;
  my $t2=shift;

  my @a1=split(/:/,$t1);
  my @a2=split(/:/,$t2);
  
  my ($minf,$secv,$hrf,$minv,$hrv,$tts);

  if ( ($a1[2]+$a2[2]) >= 60)
  {
    $minf=1;
    $secv=($a1[2]+$a2[2]) -60;
  }
  else
  {
    $minf=0;
    $secv=($a1[2]+$a2[2]);
  }

  if(($a1[1]+$a2[1]+$minf)>= 60) 
  {
    $hrf=1;
    $minv=($a1[1]+$a2[1]+$minf) -60;
  }
  else
  {
    $hrf=0;
    $minv=($a1[1]+$a2[1]+$minf);
  }
  $hrv=$a1[0]+$a2[0]+$hrf;
  $tts=sprintf("%02d:%02d:%02d",$hrv,$minv,$secv);
  return $tts;
}
