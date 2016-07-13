#!/bin/bash

source /etc/profile

rvm gemset use default &>/dev/null

exec serf-agent.rb $*
