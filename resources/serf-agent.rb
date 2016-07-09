#!/usr/bin/env ruby

require 'netaddr'
require 'system/getifaddrs'

USERDATA="/var/lib/cloud/instance/user-data.txt"

discover_net = nil
cluster_domain = nil

if File.exist?USERDATA
    File.open(USERDATA).each do |line|
        unless line.match(/^\s*PRIVATE_NET=[^\s]*\s*$/).nil?
            discover_net = line.match(/^\s*PRIVATE_NET=(?<value>[^\s]*)\s*$/)[:value]
        end
        unless line.match(/^\s*CDOMAIN=[^\s]*\s*$/).nil?
            cluster_domain = line.match(/^\s*CDOMAIN=(?<value>[^\s]*)\s*$/)[:value]
        end
        unless line.match(/^\s*SERF_KEY=[^\s]*\s*$/).nil?
            encrypt_key = line.match(/^\s*SERF_KEY=(?<value>[^\s]*)\s*$/)[:value]
        end

    end
end

# Initialize network device
unless discover_net.nil?
    System.get_all_ifaddrs.each do |netdev|
        if IPAddr.new(discover_net).include?(netdev[:inet_addr])
            discover_dev = netdev
        end
    end
end
if cdomain.nil?
    cdomain = "redborder.cluster"
end


## vim:ts=4:sw=4:expandtab:ai:nowrap:formatoptions=croqln:
