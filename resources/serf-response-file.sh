#!/bin/bash

FILE=$1
SPLITSIZE=900

if [ "x$FILE" != "x" -a -f "$FILE" -a -s "$FILE" ]; then
  read file_part

  echo ${file_part} | grep -q "^[0-9][0-9]*$"

  if [ $? -ne 0 ]; then
  	# always return header information under error
  	file_part=0
  fi

  # split file into 900 bytes blocks
  TEMP_FILE=$(mktemp -u /tmp/file-split-XXXXXX-)
  split -b $SPLITSIZE $FILE $TEMP_FILE

  SIZE=$(stat -c "%s" $FILE)
  MD5=$(md5sum $FILE | awk '{print $1}')
  SPLIT=$(ls ${TEMP_FILE}* 2>/dev/null | wc -l)

  if [ ${file_part} -eq 0 ]; then
  	# requesting header information
  	echo "{ \"size\" : \"$SIZE\" , \"md5\" : \"$MD5\" , \"split\" : \"$SPLIT\" }"
  else
  	# requesting the file content
  	count=1
  	for file_split in $(ls ${TEMP_FILE}* 2>/dev/null); do
  		if [ ${file_part} -eq $count ]; then
  			cat ${file_split}
  			break
  		fi
  		count=$(($count+1))
  	done
  fi
  rm -f ${TEMP_FILE}*

  exit 0
fi
