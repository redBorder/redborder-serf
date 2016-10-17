#!/bin/bash

#Default values
SERF_BIN=serf
ALLOWED_ROLES="core|full"
OUR_HOSTNAME=$(hostname -s)

#Wrapper for exit command that clean leader tags in errors.
function exit_function() {
    echo "Cleaning leader tag due to error"
    $SERF_BIN tags -delete leader
    exit $*
}

#
# Function to determine if there are any node with leader tag. It sets a variable named
# leader_chosen to "yes" if there is a leader node or "no", if not.
# If first argument is setted, function filter members result to find a leader with a different
# name that indicated in the argument, to determine if there are other leaders. Result is
# indicated in another_leader variable with yes or no.
# If there are errors script will be exited.
#
function isThereLeader() {
    leader_chosen="no"
    another_leader="no"
    leader_members_result=$($SERF_BIN members -format=json -tag leader="inprogress|ready" -status alive)
    if [ $? -eq 0 ] ; then
        [ "xnull" = "x$(echo $leader_members_result | jq -r .members)" ] || leader_chosen="yes"
        if [ "x$1" != "x" -a "x$leader_chosen" = "xyes" ] ; then
            other_leader_names=$(echo $leader_members_result | jq -r .members[].name)
            if [ $? -eq 0 ] ; then
                echo $other_leader_names | tr ' ' '\n' | grep -v $1 > /dev/null
                [ $? -eq 0 ] && another_leader="yes"
            else
                echo "Error parsing leader members result"
                echo $other_leader_names
                exit_function 2
            fi
        fi
    else
        echo "Error in serf members command when trying to get leader nodes!!"
        echo $leader_members_result
        exit_function 1;
    fi
}

#
# Function to get lowest IP registered by Serf. You can add -tag params to filter by tag the result.
# If there are errors, script will be exited.
#
function lowestIP() {
    ip_members_result=$($SERF_BIN members $* -format=json -status alive)
    if [ $? -eq 0 ] ; then
        if [ "x$(echo $ip_members_result | jq -r .members)" != "xnull" ] ; then
            ip_list=$(echo $ip_members_result | jq -r .members[].addr)
            if [ $? -eq 0 ] ; then
                lowest_ip=$(echo $ip_list | tr ' ' '\n' | sort | awk '{split($0,a,":"); print a[1]}' | head -n1)
            else
                echo "Error parsing serf members response"
                exit_function 3;
            fi
        else
            #Valid lowest ip not found
            lowest_ip=""
        fi
    else
        echo "Error in serf members command when trying to get lowest ip!!"
        echo $ip_members_result
    fi
}

#
# Function to get IP of this node using Serf
#
function get_myip() {
    my_ip="null"
    ip_members_result=$($SERF_BIN members -name $OUR_HOSTNAME -format=json -status alive)
    if [ $? -eq 0 ] ; then
        ip_result=$(echo $ip_members_result | jq -r .members[].addr)
        if [ $? -eq 0 ] ; then
            my_ip=$(echo $ip_result | awk '{split($0,a,":"); print a[1]}')
        else
            echo "Error parsing serf members response"
            exit_function 3;
        fi
    else
        echo "Error in serf members command when trying to get lowest ip!!"
        echo $ip_members_result
    fi

}

function whereIsChef() {
    query_response=$(serf query -timeout=250ms -format json chef-server-location)
    chef_location=""
    if [ $? -eq 0 ] ; then
        chef_location=$(echo $query_response | jq -r '.Responses | keys[0] as $key | .[$key]' 2> /dev/null)
    fi
}

#Usage function
function usage() {
    echo "rb_serf_join.sh <OPTIONS>"
    echo "  h) usage"
    echo "  r) allowed roles: regex with roles that can be cluster leaders By default: full|core"
}

function check_leader_ready() {
    leader_status="inprogress"
    while [ "x$leader_status" = "xinprogress" ] ; do
        query_response=$($SERF_BIN members -format json -tag leader=ready)
        if [ "x$(echo $query_response | jq -r .members)" = "xnull" ] ; then
            echo "Leader is not ready yet, waiting 10 seconds..."
            leader_status="inprogress"
            sleep 10
        elif [ "x$(echo $query_response | jq -r .members[0].tags.leader)" = "xready" ] ; then
            echo "Leader ready!"
            leader_status="ready"
        else
            echo "Error getting leader info"
            leader_status="error"
        fi
    done
}
##################################################
# MAIN EXECUTION
##################################################

#Getting options
while getopts "hr:o:" opt ; do
    case $opt in
        h) usage;;
        r) ALLOWED_ROLES=$OPTARGS;;
        o) OUR_HOSTNAME=$OPTARGS;;
    esac
done

LEADER_RESULT=custom

#Check if serf agent is running
systemctl is-active serf.service > /dev/null
if [ $? -ne 0 ] ; then
    echo "Serf is not running, exiting..."
else
    whereIsChef
    if [ "x$chef_location" != "x" ] ; then
        echo "Chef already configured, leader is not necessary"
        leader_status="ready"
    else
        #Is there leader?
        isThereLeader
        #If there is a leader node, I am not a leader node.
        if [ "x$leader_chosen" = "xyes" ] ; then
            echo "There is already a leader node"
        else
            lowestIP -tag mode="$ALLOWED_ROLES"
            #TODO: GET MY IP (THIS IS A POC)
            get_myip
            #If there is a node with lowest ip, i am not a leader node
            if [ "x$my_ip" != "x$lowest_ip" ] ; then
                $SERF_BIN tags -delete leader
                echo "This node is not leader"
            else
                #If i am the node with lowest ip, i am a temporal leader
        	    $SERF_BIN tags -set leader=inprogress
                EXIT=no
                counter=0
                while [ "x$EXIT" = "xno" -a $counter -le 10 ] ; do
                    #Wait to detect if there is another recent leader
                    sleep 2
                    #Is there another leader?
                    isThereLeader $OUR_HOSTNAME
                    if [ "x$another_leader" = "xno" ] ; then
        	              echo "This node is the new leader";
                        LEADER_RESULT=leader
                        EXIT=yes
                    else
                        #Am I the lowest IP of leader nodes?
                        lowestIP -tag leader=inprogress
                        #If not, I am not a leader node
                        if [ "x$my_ip" != "x$lowest_ip" ] ; then
                            echo "Found other leader, deleting leader tag for this node"
                            $SERF_BIN tags -delete leader
                            EXIT=yes
                        fi
                    fi
                    let counter=counter+1
                done
            fi
        fi
    fi
    # Execution of post configuration scripts when leader have been chosen
    if [ "x$LEADER_RESULT" = "xleader" ] ; then
        rb_configure_leader.sh
        $SERF_BIN tags -set leader=ready
    else
        if [ "x$leader_status" != "xready" ] ; then
          check_leader_ready
          if [ "x$leader_status" = "xready" ] ; then
            rb_configure_custom.sh #$chef_location
          fi
        else
          rb_configure_custom.sh #$chef_location
        fi
    fi
fi
