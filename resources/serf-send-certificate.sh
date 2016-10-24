#!/bin/bash

CERT=$1
SPLITSIZE=900

if [ "x$CERT" != "x" -a -f "$CERT" -a -s "$CERT" ]; then
  read cert_part

  echo ${cert_part} | grep -q "^[0-9][0-9]*$"

  if [ $? -ne 0 ]; then
  	# always return part 1 under error
  	cert_part=0
  fi

  # split certificate into 900 bytes blocks
  split -b $SPLITSIZE $CERT /tmp/cert_split-

  SIZE=$(stat -c "%s" $CERT)
  MD5=$(md5sum $CERT | awk '{print $1}')
  SPLIT=$(ls /tmp/cert_split-* 2>/dev/null | wc -l)

  if [ ${cert_part} -eq 0 ]; then
  	# requesting header information
  	echo "{ \"size\" : \"$SIZE\" , \"md5\" : \"$MD5\" , \"split\" : \"$SPLIT\" }"
  else
  	# requesting the file content
  	count=1
  	for cert_split in $(ls /tmp/cert_split-* 2>/dev/null); do
  		if [ ${cert_part} -eq $count ]; then
  			cat ${cert_split}
  			break
  		fi
  		count=$(($count+1))
  	done
  fi
  rm -f /tmp/cert_split-*

  exit 0
fi
