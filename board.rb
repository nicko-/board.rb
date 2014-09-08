require 'sinatra'
require 'sequel'

$config = { :board_name => 'board.rb',
            :db_url => 'sqlite://board.db'}

get '/' do
  erb :index
end
