#!/bin/bash

location_file=$1
if [ -f $location_file ] ; then
    cat $location_file | tr -d "\n"
fi
