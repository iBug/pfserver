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
  class Item
    attr_accessor :host, :port, :vmid, :enabled

    def initialize(host, port, vmid, enabled)
      # Source port is external
      @host, @port, @vmid, @enabled = host, port, vmid, enabled
    end

    def select host: nil, port: nil, vmid: nil, enabled: nil
    end

    def to_json(state = nil)
      [@host, @port, @vmid, @enabled].to_json
    end

    def self.from_json json
      self.new *JSON.load(json)
    end
  end

  @@table = {}
  class << self
    def exist? src
      !src.nil? && @@table.key?(src)
    end

    def enabled? src
      !src.nil? && @@table.key?(src) && @@table[src][3]
    end

    def select src: nil, host: nil, port: nil, vmid: nil, enabled: nil
      @@table.select do |t_src, (t_host, t_port, t_vmid, t_enabled)|
        (src.nil? || src == t_src) &&
        (host.nil? || host == t_host) &&
        (port.nil? || port == t_port) &&
        (vmid.nil? || vmid == t_vmid) &&
        (enabled.nil? || enabled == t_enabled)
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
      before_count - @@table.length
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
      (PORT_START..PORT_END).to_a.shuffle!.each do |port|
        return port unless exist? port
      end
      fail "No port available"
    end

    def load
      return unless File.file? DATA_FILE
      @@table = JSON.parse(File.read DATA_FILE).transform_keys &:to_i
    end

    def save
      File.open DATA_FILE, 'w' do |f|
        f.write JSON.generate @@table
      end
    end
  end
end
