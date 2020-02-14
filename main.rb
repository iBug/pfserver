require 'sinatra'
require 'json'
require 'iptables'

set :port, 1024

get '/' { "taoky strong\n" }

get %r{/forwards/(\d+)} do |vmid|
  vmid = vmid.to_i
  IPtables.select(vmid: vmid).map do |src, (host, port, vmid)|
    {:src => src, :host => host, :port => port}
  end.to_json
end

post %r{/forwards/(\d+)/add} do |vmid|
  vmid = vmid.to_i
  data = JSON.parse request.body.read
  next 400, "" unless data.is_a? Array
  data.map do |item|
    IPtables.add item["src"], item["host"], item["port"], item.fetch("vmid", nil)
  end.to_json
end

post %r{/forwards/(\d+)/delete} do |vmid|
  vmid = vmid.to_i
  data = JSON.parse request.body.read
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
end

not_found do
  body ""
end

IPtables.reset!
