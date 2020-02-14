#!/usr/bin/ruby

require 'sinatra'
require 'json'
require './iptables'

set :port, 1024

get '/' do
  "taoky strong\n"
end

get %r{/forwards/(\d+)} do |vmid|
  vmid = vmid.to_i
  IPtables.select(vmid: vmid).map do |src, (host, port, vmid)|
    {:src => src, :host => host, :port => port}
  end.to_json
end

post %r{/forwards/(\d+)/add} do |vmid|
  begin
    vmid = vmid.to_i
    data = JSON.parse(request.body.read || "null")
    next 400, "" unless data.is_a? Array
    data.map do |item|
      IPtables.add item["src"], item["host"], item["port"], vmid: vmid
    end.to_json
  ensure
    IPtables.save
  end
end

post %r{/forwards/(\d+)/delete} do |vmid|
  begin
    vmid = vmid.to_i
    data = JSON.parse(request.body.read || "null")
    case data
    when Array
      data.map do |item|
        src = item.fetch("src", nil)
        host = item.fetch("host", nil)
        port = item.fetch("port", nil)
        IPtables.delete src, host, port, vmid
      end
    else
      IPtables.delete vmid: vmid
    end.to_json
  ensure
    IPtables.save
  end
end

post "/flush" do
  begin
    IPtables.flush.to_s
  ensure
    IPtables.save
  end
end

get "/nextport" do
  IPtables.next_port.to_s
end

not_found do
  body ""
end

IPtables.load
IPtables.flush
