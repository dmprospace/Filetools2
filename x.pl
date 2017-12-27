$filename='asas1`287817  2537-0@#$%^&  (+_)(&^%$#@!,.\';lk=-;';
print "\n$filename\n\n";


                              $filename =~ s/`/\\`/g;
                              $filename =~ s/@/\\@/g;
                              $filename =~ s/!/\\!/g;
                              $filename =~ s/\$/\\\$/g;
                              $filename =~ s/\^/\^/g;
                              $filename =~ s/&/\\&/g;
                              $filename =~ s/\(/\\\(/g;
                              $filename =~ s/\)/\\\)/g;
                              $filename =~ s/\^/\\\^/g;
                              $filename =~ s/,/\\,/g;
                              $filename =~ s/'/\\'/g;
                              $filename =~ s/;/\\;/g;
                              $filename =~ s/=/\\=/g;


print "\n$filename\n\n";


