#!/bin/bash

source /etc/profile

rvm gemset use default

exec serf-agent-post.rb $*
