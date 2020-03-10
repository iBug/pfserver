require "time"
require "net/http"

module LogD
  KEY_RE = %r!\[vlab:\S+\]!

  class LogParser
    def initialize(file)
      @file = file
    end

    def run
      IO.popen(["tail", "-F", @file]).each_line do |line|
        line.chomp!
        next if line.scan(KEY_RE).empty?
        pref, content = line.split KEY_RE, 2
        time = Time.parse pref
        data = {:flags => Set.new}
        content.split.each do |item|
          key, value = item.split "="
          if value.nil?
            data[:flags] << key
          else
            data[key] = value
          end
        end
        yield (time, data)
      end
    end

    def run_background
      Thread.new do
        run &block
      end
    end
  end
end
