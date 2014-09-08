require 'sinatra'
require 'sequel'
require 'digest'

$config = { :board_name => 'board.rb',
            :db_url => 'sqlite://board.db' }

$db = Sequel.connect $config[:db_url]

before '/*' do
  # Handle user authentication
  if request.cookies['s'].nil?
    # Generate client, server secrets and hashes
    client_secret = Random.new.bytes(64)
    server_secret = Random.new.bytes(64)
    hash = Digest::MD5.hexdigest "#{client_secret}#{server_secret}"

    # Store in database, also send to client
    $db[:auth].insert :client_secret => client_secret.bytes.map {|i| i.to_s(16).rjust(2, '0')}.join,
                      :server_secret => server_secret.bytes.map {|i| i.to_s(16).rjust(2, '0')}.join,
                      :hash => hash

    # Send client secret to client
    response.set_cookie 's', { :value => client_secret.bytes.map {|i| i.to_s(16).rjust(2, '0')}.join, 
                               :path => '/',
                               :expires => Time.at(2000000000) }

    @user = hash
  else
    # Read hash from database
    @user = $db[:auth].where(:client_secret => request.cookies['s']).first[:hash]
  end
end

get '/' do
  erb :global do
    'test'
  end
end

get '/me/' do
  erb :me, :layout => :global
end

get '/compose/' do
  erb :compose, :layout => :global
end