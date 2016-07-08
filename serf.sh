#!/bin/bash

source /etc/profile
[ -f /var/lib/cloud/instance/user-data.txt ] && source /var/lib/cloud/instance/user-data.txt

rvm gemset use default

exec serf.rb $*
