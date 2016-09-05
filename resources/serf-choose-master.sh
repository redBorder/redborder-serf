#!/bin/bash

#Default values
SERF_BIN=serf
ALLOWED_ROLES="master|corezk|core|undef"
OUR_HOSTNAME=$(hostname -s)


#Wrapper for exit command that clean master tags in errors.
function exit_function() {
    echo "Cleaning master tag due to error"
    $SERF_BIN tags -delete master
    exit $*
}

#
# Function to determine if there are any node with master tag. It sets a variable named
# master_chosen to "yes" if there is a master node or "no", if not.
# If first argument is setted, function filter members result to find a master with a different
# name that indicated in the argument, to determine if there are other masters. Result is
# indicated in another_master variable with yes or no.
# If there are errors script will be exited.
#
function isThereMaster() {
    master_chosen="no"
    another_master="no"
    master_members_result=$($SERF_BIN members -format=json -tag master="inprogress|ready" -status alive)
    if [ $? -eq 0 ] ; then
        [ "xnull" = "x$(echo $master_members_result | jq -r .members)" ] || master_chosen="yes"
        if [ "x$1" != "x" -a "x$master_chosen" = "xyes" ] ; then
            other_master_names=$(echo $master_members_result | jq -r .members[].name)
            if [ $? -eq 0 ] ; then
                echo $other_master_names | tr ' ' '\n' | grep -v $1 > /dev/null
                [ $? -eq 0 ] && another_master="yes"
            else
                echo "Error parsing master members result"
                echo $other_master_names
                exit_function 2
            fi
        fi
    else
        echo "Error in serf members command when trying to get master nodes!!"
        echo $master_members_result
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

#Usage function
function usage() {
    echo "rb_serf_join.sh <OPTIONS>"
    echo "  h) usage"
    echo "  r) allowed roles: regex with roles that can be cluster masters By default: master|corezk|core|undef"
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

MASTER_RESULT=custom

#Check if serf agent is running
systemctl is-active serf.service > /dev/null
if [ $? -ne 0 ] ; then
    echo "Serf is not running, exiting..."
else
    #Is there master?
    isThereMaster
    #If there is a master node, I am not a master node.
    if [ "x$master_chosen" = "xyes" ] ; then
        echo "There is already a master node"
    else
        lowestIP -tag mode="$ALLOWED_ROLES"
        #TODO: GET MY IP (ESTE ES DE PRUEBA)
        get_myip
        #If there is a node with lowest ip, i am not a master node
        if [ "x$my_ip" != "x$lowest_ip" ] ; then
            $SERF_BIN tags -delete master
            echo "This node is not master"
        else
            #If i am the node with lowest ip, i am a temporal master
    	    $SERF_BIN tags -set master=inprogress
            EXIT=no
            counter=0
            while [ "x$EXIT" = "xno" -a $counter -le 10 ] ; do
                #Wait to detect if there is another recent master
                sleep 2
                #Is there another master?
                isThereMaster $OUR_HOSTNAME
                if [ "x$another_master" = "xno" ] ; then
    	              echo "This node is the new master";
                    MASTER_RESULT=master
                    EXIT=yes
                else
                    #Am I the lowest IP of master nodes?
                    lowestIP -tag master=inprogress
                    #If not, I am not a master node
                    if [ "x$my_ip" != "x$lowest_ip" ] ; then
                        echo "Found other master, deleting master tag for this node"
                        $SERF_BIN tags -delete master
                        EXIT=yes
                    fi
                fi
                let counter=counter+1
            done
        fi
    fi
    # Execution of post configuration scripts when master have been chosen
    if [ "x$MASTER_RESULT" = "xmaster" ] ; then
        rb_configure_master.sh
        $SERF_BIN tags -set master=ready
    else
        rb_configure_custom.sh
    fi
fi
