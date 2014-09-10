require 'sinatra'
require 'sequel'
require 'digest'

$config = { :board_name => 'board.rb',
            :db_url => 'sqlite://board.db' }

$db = Sequel.connect $config[:db_url]

helpers do
  def h text
    Rack::Utils.escape_html text
  end
end

before '/*' do
  # Handle user authentication
  if request.cookies['s'].nil? or request.cookies['h'].nil?
    # Generate client, server secrets and hashes
    client_secret = Random.new.bytes(64)
    server_secret = Random.new.bytes(64)
    hash = Digest::MD5.hexdigest "#{client_secret}#{server_secret}"

    # Store in server secret and hash in database, send client secret to client
    $db[:auth].insert :server_secret => server_secret.bytes.map {|i| i.to_s(16).rjust(2, '0')}.join,
                      :hash => hash

    # Send client secret to client
    response.set_cookie 's', { :value => client_secret.bytes.map {|i| i.to_s(16).rjust(2, '0')}.join, 
                               :path => '/',
                               :expires => Time.at(2147483640) }

    # Send userhash to client
    response.set_cookie 'h', { :value => hash, :path => '/', :expires => Time.at(2147483640) }

    @user = hash
  else
    # Attempt to authenticate user
    row = $db[:auth].where(:hash => request.cookies['h']).first

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'No such user with that hash.'}) \
      if row.nil?

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'Provided hash does not match server generated.') \
      if Digest::MD5.hexdigest("#{[request.cookies['s']].pack('H*')}#{[row[:server_secret]].pack('H*')}") != request.cookies['h']

    # Set @user
    @user = request.cookies['h']
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

get '/new_post/' do
  erb :new_post, :layout => :global
end

post '/new_post/' do
  $db[:posts].insert :author => @user, :content => params[:content], :date => Time.now.to_i,
                     :tags => (params[:tags] or ''), :in_reply_to => params[:reply]

  redirect to('/') # TODO, redirect to new thread once done
end

get '/t/:id/' do
  erb :thread, :layout => :global
end
