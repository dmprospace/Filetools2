(
    cat <<____HERE
Subject: $subject
To: $recipients
Mime-Version: 1.0
Content-type: multipart/related; boundary="$boundary"

--$boundary
Content-type: text/plain
Content-transfer-encoding: 7bit

____HERE

    # Read message body from stdin
    # Maybe apply quoted-printable encoding if you anticipate
    # overlong lines and/or 8-bit character codes
    cat

    cat <<____HERE

--$boundary
Content-type: application/octet-stream; name="$file"
Content-disposition: attachment; filename="$file"
Content-transfer-encoding: base64

____HERE

    # If you don't have base64 you will have to reimplement that, too /-:
    /usr/bin/base64 "$file"

    cat <<____HERE
--$boundary--
____HERE

) | sendmail -oi -t

