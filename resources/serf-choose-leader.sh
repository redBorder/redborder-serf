#!/bin/bash

#Wrapper for exit command that clean leader tags in errors.
function exit_function() {
    echo "WARNING: cleaning leader tag due to error"
    $SERF_BIN tags -delete $leader_tag_key > /dev/null
    echo "Exiting..."
    exit $*
}

#
# Function that detects leader by its leader tag key and sets leader_count
# variable to the number of leaders that have been detected
#
function countLeaders() {
    serf_members="$($SERF_BIN members -status alive)"
    if [ $? -eq 0 ] ; then
        leader_list=$(echo "$serf_members" | grep ${leader_tag_key}= | awk '{print $1}')
        leader_count=0
        for leader_node in $leader_list ; do let leader_count=leader_count+1 ; done
    else
        echo "ERROR: failed to use serf ($serf_members)"
        exit_function 1
    fi
}

#
# Function to get lowest IP registered by Serf. You can add a pattern in first param to filter the result.
# If there are errors, script will be exited.
#
function lowestIP() {
    filter=$1
    #Applying filter
    if [ "x$filter" != "x" ] ; then
        serf_members=$($SERF_BIN members -status alive | grep -i $filter)
    else
        serf_members=$($SERF_BIN members -status alive -tag "$CANDIDATES_TAG")
    fi
    lowest_ip=$(echo "$serf_members" | awk '{print $2}' | cut -d ':' -f 1 | sort | head -n1)    
}

#
# Function to get IP of this node using Serf
#
function get_myip() {
    my_ip="null"
    ip_members_result=$($SERF_BIN members -name $HOSTNAME -format=json -status alive)
    if [ $? -eq 0 ] ; then
        ip_result=$(echo $ip_members_result | jq -r .members[].addr)
        if [ $? -eq 0 ] ; then
            my_ip=$(echo $ip_result | awk '{split($0,a,":"); print a[1]}')
        else
            echo "ERROR (in get_myip function): can't parse serf members response"
            exit_function 3;
        fi
    else
        echo "ERROR (in get_myip function): serf members command failed when trying to get lowest ip"
        echo $ip_members_result
        exit_function 4
    fi
}

# Usage function.
function usage() {
    echo
    echo "$(basename $0) <OPTIONS>"
    echo "  h) usage"
    echo "  c) candidates tag: key=<regex> used to detect if a node can be a candidate become leader"
    echo "  r) ready tag: If this key=value tag exists, no leader election is performed."
    echo "  t) leader tag: key=value tag that is assigned to node if it becomes leader"
    echo "  l) leader script: script that must be executed when the node is determined as leader"
    echo "  f) follower script: script that must be executed when the node is determined as a follower"
    echo "  n) hostname: indicate hostname of this node. It's calculated using hostname command by default"
    echo "  b) serf bin: to indicate where is serf binary. By default, is searched in the path"
    echo
}

##################################################
# MAIN EXECUTION
##################################################

#Default parameter values
SERF_BIN=serf
HOSTNAME=$(hostname -s)
CANDIDATES_TAG="mode=chef|full"
READY_TAG="consul=ready"
LEADER_TAG="leader=wait"
LEADER_SCRIPT=""
FOLLOWER_SCRIPT=""

#Getting options
while getopts "hc:r:t:l:f:n:b:" opt ; do
    case $opt in
        h) usage; exit 0;;
        c) CANDIDATES_TAG=$OPTARG;;
        r) READY_TAG=$OPTARG;;
        t) LEADER_TAG=$OPTARG;;
        l) LEADER_SCRIPT=$OPTARG;;
        f) FOLLOWER_SCRIPT=$OPTARG;;
        n) HOSTNAME=$OPTARG;;
        b) SERF_BIN=$OPTARG;;
    esac
done

#Checking options
for tag in "$CANDIDATES_TAG $READY_TAG $LEADER_TAG" ; do
    echo $tag | grep -q "^.*=.*$"
    if [ $? -ne 0 ] ; then 
        echo "ERROR: Option tag $tag is not valid, must be key=<regex>"
        exit 1
    fi
done

leader_flag=1 #By default, follower script should be executed
leader_tag_key=$(echo $LEADER_TAG | cut -d '=' -f 1)

#Check if READY_TAG is set in a node
serf members -tag $READY_TAG | grep -q $READY_TAG
if [ $? -eq 0 ] ; then
    echo "INFO: Ready tag ($READY_TAG) detected, this node is a follower"
else
    #Is there leader?
    countLeaders
    #If there are more than 0 leaders, I am not a leader
    if [ $leader_count -gt 0 ] ; then
        echo "INFO: There is already a leader node (leader tag = $leader_tag_key), this node is a follower"
    else
        lowestIP
        get_myip
        #If there is a node with lowest ip, i am not a leader node
        if [ "x$my_ip" != "x$lowest_ip" ] ; then
            $SERF_BIN tags -delete $leader_tag_key > /dev/null
            echo "INFO: this node is a follower (leader tag = $leader_tag_key)"
        else
            #If i am the node with lowest ip, i am a temporal leader
            echo "INFO: becoming a provisional leader... (leader tag = $leader_tag_key)"
    	    $SERF_BIN tags -set $LEADER_TAG > /dev/null
            EXIT=no
            counter=0
            while [ "x$EXIT" = "xno" -a $counter -le 10 ] ; do
                #Wait to detect if there is another recent leader
                sleep 2
                #Is there another leader?
                countLeaders
                if [ $leader_count -eq 1 ] ; then
    	              echo "INFO: this node is the new leader (leader tag = $leader_tag_key)";
                    leader_flag=0
                    EXIT=yes
                else
                    #Am I the lowest IP of leader nodes?
                    lowestIP ${leader_tag_key}= 
                    #If not, I am not a leader node
                    if [ "x$my_ip" != "x$lowest_ip" ] ; then
                        echo "INFO: another leader was found, deleting leader tag for this node (leader tag = $leader_tag_key)"
                        $SERF_BIN tags -delete $leader_tag_key > /dev/null
                        EXIT=yes
                    fi
                fi
                let counter=counter+1
            done
            [ $counter -gt 10 ] && echo "WARNING: there was a convergence problem electing leader (leader tag = $leader_tag_key), could be duplicates!!"
        fi
    fi
fi
# Execution of post-scripts
if [ $leader_flag -eq 0 ] ; then
    if [ "x$LEADER_SCRIPT" != "x" ] ; then
        echo "Leader script will be executed"
        exec $LEADER_SCRIPT
    fi
else
    if [ "x$FOLLOWER_SCRIPT" != "x" ] ; then
        echo "Follower script will be executed"
        exec $FOLLOWER_SCRIPT
    fi
fi
