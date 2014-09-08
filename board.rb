require 'sinatra'
require 'sequel'

get '/' do
  erb :index
end