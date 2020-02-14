require 'sinatra'
require 'json'

DATA_FILE = "data.json"
PORT_START = 10001
PORT_END = 29999

def iptables args
  if Sinatra::Base.production?
    system "iptables", *args
  else
    puts "iptables #{args.join ' '}"
    true
  end
end

module IPtables
  @@table = {}
  class << self
    def exist? src
      src.nil? || @@table.key?(src)
    end

    def select src: nil, host: nil, port: nil, vmid: nil
      @@table.select do |t_src, (t_host, t_port, t_vmid)|
        (src.nil? || src == t_src) &&
        (host.nil? || host == t_host) &&
        (port.nil? || port == t_port) &&
        (vmid.nil? || vmid == t_vmid)
      end
    end

    def add src, host, port, vmid: nil
      return if exist? src
      src ||= next_port
      if iptables %w{-t nat -A VLAB_STUDENT -p tcp -m tcp --dport} + [src.to_s] +
          %w{-j DNAT --to-destination} + ["#{host}:#{port}"]
        @@table[src] = [host, port, vmid]
        src
      end
    end

    def delete src: nil, host: nil, port: nil, vmid: nil
      before_count = @@table.length
      @@table.reject! do |t_src, (t_host, t_port, t_vmid)|
        if (src.nil? || src == t_src) &&
          (host.nil? || host == t_host) &&
          (port.nil? || port == t_port) &&
          (vmid.nil? || vmid == t_vmid)
          iptables %w{-t nat -D VLAB_STUDENT -p tcp -m tcp --dport} + [t_src.to_s] +
            %w{-j DNAT --to-destination} + ["#{t_host}:#{t_port}"]
        end
      end
      @@table.length - before_count
    end

    def clear
      @@table.clear
    end

    def reset
      iptables %w{-t nat -F VLAB_STUDENT}
    end

    def flush
      reset
      @@table.select! do |src, (host, port, vmid)|
        iptables %w{-t nat -A VLAB_STUDENT -p tcp -m tcp --dport} + [src.to_s] +
          %w{-j DNAT --to-destination} + ["#{host}:#{port}"]
      end
      length
    end

    def length
      @@table.length
    end

    def next_port
      (PORT_START..PORT_END).each do |port|
        return port unless exist? port
      end
      fail "No port available"
    end

    def load
      @@table = JSON.parse File.read DATA_FILE if File.file? DATA_FILE
      @@table.transform_keys! do |key|
        key.to_i
      end
    end

    def save
      File.open DATA_FILE, 'w' do |f|
        f.write JSON.generate @@table
      end
    end
  end
end
