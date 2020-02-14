require 'sinatra'
require 'json'

DATA_FILE = "data.json"

def iptables *args
  if Sinatra::Base.production?
    system "iptables", *args
  else
    puts "iptables #{args.join ' '}"
  end
end

module IPtables
  @@table = JSON.parse File.read DATA_FILE
  class << self
    def exist? src
      @@table.key? src
    end

    def select src = nil, host = nil, port = nil, vmid = nil
      @@table.select do |t_src, (t_host, t_port, t_vmid)|
        (src.nil? || src == t_src) &&
        (host.nil? || host == t_host) &&
        (port.nil? || port == t_port) &&
        (vmid.nil? || vmid == t_vmid)
      end
    end

    def add src, host, port, vmid = nil
      return false if exist? src
      iptables %w{-t nat -A VLAB_STUDENT -p tcp -m tcp --dport} + [src.to_s] +
        %w{-j DNAT --to-destination} + ["#{host}:#{port}"]
      @@table[src] = [host, port, vmid]
      true
    end

    def delete src = nil, host = nil, port = nil, vmid = nil
      @@table.reject! do |t_src, (t_host, t_port, t_vmid)|
        if (src.nil? || src == t_src) &&
          (host.nil? || host == t_host) &&
          (port.nil? || port == t_port) &&
          (vmid.nil? || vmid == t_vmid)
          iptables %w{-t nat -D VLAB_STUDENT -p tcp -m tcp --dport} + [t_src.to_s] +
            %w{-j DNAT --to-destination} + ["#{t_host}:#{t_port}"]
          true
        end
      end
    end

    def clear
      @@table.clear
    end

    def flush
      iptables %w{-t nat -F VLAB_STUDENT}
    end

    def reset!
      flush
      @@table.each do |src, (host, port, vmid)|
        iptables %w{-t nat -A VLAB_STUDENT -p tcp -m tcp --dport} + [src.to_s] +
          %w{-j DNAT --to-destination} + ["#{host}:#{port}"]
      end
    end

    def length
      @@table.length
    end

    def load
      @@table = JSON.parse File.read DATA_FILE
    end

    def save
      File.open DATA_FILE, 'w' do |f|
        f.write JSON.dump $table
      end
    end
  end
end
