#!/bin/bash

SERF_BIN=/root/serf

function isThereMaster() {
    master_chosen="no"
    master_members=$($SERF_BIN members -format=json -tag master=yes -status alive)
    [ "xnull" = "x$(echo $master_members | jq -r .members)" ] || master_chosen="yes"
}
function isThereAnotherMaster() {
    another_master="no"
    other_master_members=$($SERF_BIN members -format=json -tag master=yes -status alive | jq -r .members[].name | grep -v $(hostname -f)| grep -v null)
    [ "x$other_master_members" = "x" ] || another_master="yes"
}

#Function to get lowest IP registered by Serf. You can add -tag params to filter
function lowestIP() {
    lowest_ip=$($SERF_BIN members $* -format=json -status alive | jq -r .members[].addr | sort | awk '{split($0,a,":"); print a[1]}' | head -n1)
}

#Usage function
function usage() {
    echo "TODO USAGE"
}

#Getting options
while getopts "" opt ; do
    case $opt in
        h) usage;
    esac
done

#Check if serf agent is running ; TODO!!
#TODO: use systemd to get serf status

#Join to cluster
#$SERF_BIN join

#Is there master?
isThereMaster
#If there is a master node, I am not a master node.
if [ "x$master_chosen" = "xyes" ] ; then
    echo "There is already a master node"
else
    lowestIP #-tag role="master|corezk|core"
    #TODO: GET MY IP (ESTE ES DE PRUEBA)
    my_ip=$(ip a s bond0 2>/dev/null |grep inet|grep brd|awk '{print $2}'|head -n 1|tr '/' ' '|awk '{print $1}')
    #If there is a node with lowest ip, i am not a master node
    if [ "x$my_ip" != "x$lowest_ip" ] ; then
         $SERF_BIN tags -delete master
         echo "This node is not master"
    else
        #If i am the node with lowest ip, i am a temporal master
	$SERF_BIN tags -set master=yes
        EXIT=no
        while [ "x$EXIT" = "xno"  ] ; do
            #Wait to detect if there is another recent master
            sleep 2
            #Is there another master?
            isThereAnotherMaster
            if [ "x$another_master" = "xno" ] ; then
	        echo "This node is the new master";
                EXIT=yes
            else
                #Am I the lowest IP of master nodes?
                lowestIP -tag master=yes
                #If not, I am not a master node
                if [ "x$my_ip" != "x$lowest_ip" ] ; then
                    echo "Found other master, deleting master tag for this node"
                    $SERF_BIN tags -delete master
                    EXIT=yes
                fi
            fi
        done
    fi
fi
