#!/usr/bin/env ruby

require 'getopt/std'
require 'json'
require 'digest/md5'

opt = Getopt::Std.getopts("q:t:")

@query_name = opt["q"].to_s
opt["t"].nil? ? @tag_filter = "" : @tag_filter = "-tag #{opt["t"].to_s}"
@retries = 5
@timeout_slot = 250
#
# Function to get a part of a file using serf queries
#
def get_part(query_number)
    part=""
    tries = @retries
    timeout_factor = 1
    begin
        timeout = @timeout_slot * timeout_factor
        query=JSON.parse(`serf query #{@tag_filter} -timeout=#{timeout}ms -format json #{@query_name} #{query_number}`)
        if !query["Responses"].empty?
            part = query["Responses"].values[0]
        else
            raise
        end
    rescue
        STDERR.puts "WARNING: No response for query part #{query_number}, retrying #{tries} times more"
        tries -= 1
        timeout_factor = @retries - tries + 1
        retry unless tries.zero?
    end
    return part
end

#First query to get number of parts and md5
info = get_part(0)
if info.empty?
    STDERR.puts "ERROR: Can't obtain query information"
    exit 1
else
    parsed_info=JSON.parse(info)
    if !parsed_info.key?("split") or !parsed_info.key?("md5")
        STDERR.puts "ERROR: Can't get split or md5 key"
        exit 1
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
            printf "#{result}"
        else
            STDERR.puts "ERROR: MD5 Checksum failed, invalid certificate"
            exit 1
        end
    end
end
