#!/bin/bash

JOIN=$1

if [ "x$JOIN" != "x" ] ; then
	/usr/bin/serf agent -config-dir /etc/serf -join $JOIN
else
	/usr/bin/serf agent -config-dir /etc/serf
fi
