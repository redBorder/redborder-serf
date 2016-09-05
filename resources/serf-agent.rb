#!/usr/bin/env ruby

### DEPRECATED ###

require 'ipaddr'
require 'netaddr'
require 'system/getifaddrs'
require 'fileutils'
require 'json'

USERDATA="/var/lib/cloud/instance/user-data.txt"
SERFJSON="/etc/serf/00first.json"
TAGSJSON="/etc/serf/tags"

# Is there the first conf file?
if File.exist?SERFJSON
    exec("serf agent -config-dir /etc/serf")
end

# There is no first config file ... need to generate one
# This is due to be in a cloud system and need to request data
# to user-data or to be in a non cloud system but we have been
# started without executing previously the wizard config script.
#
# steps: set hostname (node name), get local ip to bind, get encrypt_key


discover_net = nil
cluster_domain = "redborder.cluster"
encrypt_key = nil
node_role = "undef"
serf_conf = {}
serf_tags = {}

if File.exist?USERDATA
    File.open(USERDATA).each do |line|
        unless line.match(/^\s*PRIVATE_NET=[^\s]*\s*$/).nil?
            discover_net = line.match(/^\s*PRIVATE_NET="?(?<value>[^\s"]*)"?\s*$/)[:value]
        end
        unless line.match(/^\s*CDOMAIN=[^\s]*\s*$/).nil?
            cluster_domain = line.match(/^\s*CDOMAIN="?(?<value>[^\s"]*)"?\s*$/)[:value]
        end
        unless line.match(/^\s*SERF_KEY=[^\s]*\s*$/).nil?
            encrypt_key = line.match(/^\s*SERF_KEY="?(?<value>[^\s"]*)"?\s*$/)[:value]
        end
        unless line.match(/^\s*NODEROLE=[^\s]*\s*$/).nil?
            node_role = line.match(/^\s*NODEROLE="?(?<value>[^\s"]*)"?\s*$/)[:value]
        end
    end
else
    # No user-data nor first config file -> error
    p "Error: need a first config file provided by the wizard config script"
    exit(1)
end

# local IP to bind to
if discover_net.nil?
    p "Error: unknown sync network (tag 'PRIVATE_NET' in user-data file)"
    exit (1)
else
    # Initialize network device
    System.get_all_ifaddrs.each do |netdev|
        if IPAddr.new(discover_net).include?(netdev[:inet_addr])
            serf_conf["bind"] = netdev[:inet_addr].to_s
        end
    end
    if serf_conf["bind"].nil?
        p "Error: no IP address to bind (PRIVATE_NET: #{discover_net})"
        exit(1)
    end
end

serf_conf["tags_file"] = TAGSJSON

# Check hostname
node_name = `hostname -s`.chomp
if node_name == "rbmanager" or node_name == "localhost"
    # setting hostname to an auto-hostname different from default
    serf_conf["node_name"] = "rb#{rand(36**10).to_s(36)}"
    system("hostnamectl set-hostname \"#{serf_conf["node_name"]}.#{cluster_domain}\"")
else
    serf_conf["node_name"] = node_name
end


# Encrypt key
unless encrypt_key.nil?
    serf_conf["encrypt_key"] = encrypt_key.to_s
end

# defined role
serf_tags["role"] = node_role

# Create json file configuration
unless File.directory?("/etc/serf")
    FileUtils.mkdir_p("/etc/serf")
end
file_serf_conf = File.open(SERFJSON,"w")
file_serf_conf.write(serf_conf.to_json)
file_serf_conf.close

# Create json tags file
file_serf_tags = File.open(TAGSJSON,"w")
file_serf_tags.write(serf_tags.to_json)
file_serf_tags.close


# Finally exec serf agent with the new configuration
exec("serf agent -config-dir /etc/serf")

## vim:ts=4:sw=4:expandtab:ai:nowrap:formatoptions=croqln:
