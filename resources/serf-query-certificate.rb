#!/usr/bin/env ruby

require 'getopt/std'
require 'json'
require 'digest/md5'

opt = Getopt::Std.getopts("q:")

@query_name=opt["q"].to_s
@retries=5
#
# Function to get a part of RSA certificate using serf queries
#
def get_part(query_number)
    part=""
    tries = @retries
    begin
        query=JSON.parse(`serf query -timeout=250ms -format json #{@query_name} #{query_number}`)
        if !query["Responses"].empty?
            part = query["Responses"].values[0]
        else
            raise
        end
    rescue
        STDERR.puts "No response for query part #{query_number}, retrying #{tries} times more"
        retry unless (tries -= 1).zero?
    end
    return part
end

#First query to get number of parts and md5
info = get_part(0)
if info.empty?
    STDERR.puts "ERROR: Can't obtain query information"
else
    parsed_info=JSON.parse(info)
    if !parsed_info.key?("split") or !parsed_info.key?("md5")
        STDERR.puts "ERROR: Can't get split or md5 key"
    else
        part=[]
        i=0
        while i < parsed_info["split"].to_i do
            part[i] = get_part(i+1)
            i=i+1
        end
        result = part.join
        md5_result = Digest::MD5.hexdigest(result)
        if md5_result == parsed_info["md5"]
            puts "#{result}"
        else
            STDERR.puts "MD5 Checksum error, invalid certificate"
        end
    end
end
