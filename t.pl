 use MIME::Lite;
    $msg = MIME::Lite->new(
                 To      =>'xyzz@yahoo.com',
                 Subject =>'HTML with in-line images!',
                 Type    =>'multipart/related'
                 );
    $msg->attach(Type => 'text/html',
                 Data => qq{ <body>
                             Here's <i>my</i> image:
                             <img src="cid:myimage.gif">
                             </body> }
                 );
    $msg->send();
