require 'sinatra'
require 'json'

set :port, 1024

DATA_FILE = "data.json"

def load_table
  $table ||= JSON.parse File.read DATA_FILE
end

def save_table
  File.open DATA_FILE, 'w' do |f|
    f.write JSON.dump $table
  end
end

load_table

get '/' do
  "taoky strong\n"
end
