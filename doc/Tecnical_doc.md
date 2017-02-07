#redborder-serf documentation

redborder-serf is a package with a set of scripts that uses Hashicorp serf tool for cluster creation. This scripts adds some necessary features to automatically bootstrap node creation and joining to the redborder cluster.

##serf dependency

First of all, we have to know that this scripts are serf-based, so they require serf agent to be running. For these reason, this repo provides a systemd unit file to execute serf as a service. In addition, for Centos 7 environment there is a RPM package to install serf in redborder repo. 

If you want to install serf for yourself you are able to do that too, but you must be sure that serf binary is in a PATH location and the configuration of must be in /etc/serf/00first.json.

##serf-join

Serf join script provides initial configuration to serf and enables it to autodiscover the rest of serf nodes even without it know any other node.

serf-join can do that using two differents methods, in function of serf configuration:

- **Multicast mode**: If serf configuration includes discover option, built-in serf multicast discovery will be used. This is the recommeded option if you are able to use multicast in your network. 
- **Unicast mode**: With this script we provide a second way to do auto-discovery in unicast restricted environemnts where you can't use multicast. An example of this kind of enviroments are AWS EC2, or in general, most of cloud providers. Nowadays they don't support multicast, so unicast mode must be use. 

Now we are going to explain deeply how unicast mode works.

** **TO DO** **

##serf-choose-leader

serf-choose-leader script is a tool to select a leader node using serf tags. It allow easily to identify a leader for a group of serf nodes and execute different scripts, depending of if node is a leader or not. 

Now we are going to explain the script options:

- **-h**: show usage
- **-c**: candidates tag. Here you have to specify the tag that nodes must have to be a leader candidate. If a node that executes the script don't have this tag assigned, it will be follower. The syntax is the following: -c key=<regex>. For example: -c mode=full|core
- **-r**: ready tag. This tag will be searched at the beginning of script execution. If exists en any node of the serf cluster, the node that executes the script will be a follower. 
- **-t**: leader tag. This is the tag that will be set in the node that become leader.  
- **-f**: follower script. This is the script (or command) that will be executed if the node becomes follower.
- **-l**: leader script. This is the script (or command) that will be executed if the node becomes leader.

In the following diagram is represented how serf-choose-leader script works

![](choose-leader.png)








