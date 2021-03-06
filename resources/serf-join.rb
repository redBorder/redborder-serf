#!/usr/bin/env ruby

require 'ipaddr'
require 'netaddr'
require 'system/getifaddrs'
require 'arp_scan'
require 'json'

def local_ip?(ip)
    ret = false
    System.get_all_ifaddrs.each do |x|
        if x[:inet_addr].to_s == ip.to_s
            # local ip address match
            ret = true
            break
        end
    end
    ret
end

# Check if a IP is member of serf cluster
def isMember?(ip)
  ret = false
  begin
    serf_members=JSON.parse(`serf members -format=json`)
    serf_members["members"].each do |member|
      if "#{ip}:7946" == member["addr"]
        ret = true
        break
      end
    end
  rescue Exception => e
    puts e.message
  end
  return ret
end

#This code will be executed when node have been joined to cluster (end of script)
def fPost
    #exec("serf-choose-leader.sh")
    exit(0)
end

USERDATA="/var/lib/cloud/instance/user-data.txt"
SERFJSON=ARGV[0]

serf_conf = {}

# Is there the first conf file?
if File.exist?SERFJSON
    file_serf_conf = File.read(SERFJSON)
    serf_conf = JSON.parse(file_serf_conf)
else
    p "Error loading serf config file #{SERFJSON}. Must be the first parameter"
    exit(1)
end

unless serf_conf["discover"].nil?
    # serf is in multicast configuration, no need to join via unicast
    fPost
end

# In unicast, we need to scan sync network to look for serf nodes

# First, get device for IP bind
discover_dev = nil
discover_net = nil
System.get_all_ifaddrs.each do |netdev|
    if netdev[:inet_addr] == serf_conf["bind"]
        discover_dev = netdev
        break
    end
end
if discover_dev.nil?
    p "Error: no devices found for IP address #{serf_conf["bind"]}"
    exit(1)
end

# Now ARP scan the sync network to look for a serf node

# Calculate the sync network based on the network from bind dev
discover_net = NetAddr::CIDR.create("#{discover_dev[:inet_addr]}/#{discover_dev[:netmask]}")

# with all the information, we can loop forever until a serf node is detected and joined
f_break = false
count = 3
while count > 0
    report_arpscan = ARPScan("-I #{discover_dev[:interface]} #{discover_net.network}#{discover_net.netmask}")
    report_arpscan.hosts.each do |host|
        # avoid own local ip
        if local_ip?(host.ip_addr) or isMember?(host.ip_addr)
            next
        end
        # trying to connect to host.ip_addr
        p "Trying to join to #{host.ip_addr}"
        ret = system("serf join #{host.ip_addr}")
    end
    # scan every 10 seconds
    count = count - 1
    p "Warning: no serf node found, trying again #{count} times" if count > 0
    sleep(1)
end

fPost

## vim:ts=4:sw=4:expandtab:ai:nowrap:formatoptions=croqln:
