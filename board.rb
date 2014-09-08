require 'sinatra'
require 'sequel'

$config = {:board_name => 'board.rb'}

get '/' do
  erb :index
end
