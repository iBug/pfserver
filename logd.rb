require "time"
require "net/http"

module LogD
  KEY_RE = %r!\[vlab:\S+\]!

  class LogParser
    def initialize(file)
      @file = file
    end

    def run &block
      IO.popen(["tail", "-F", @file]).each_line do |line|
        line.chomp!
        next if line.scan(KEY_RE).empty?
        pref, content = line.split KEY_RE, 2
        time = Time.parse pref
        data = {}
        content.split.each do |item|
          key, value = item.split "="
          data[key] = value || ''
        end
        yield (time, data)
      end
    end

    def run_background &block
      Thread.new do
        run &block
      end
  end
end
