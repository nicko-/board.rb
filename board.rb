require 'sinatra'
require 'sequel'
require 'digest'

$config = { :board_name => 'board.rb',
            :db_url => 'sqlite://board.db' }

$db = Sequel.connect $config[:db_url]

get '/' do
  erb :index
end
