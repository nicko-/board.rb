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

  # Find the original poster of a thread witb a post id
  def find_op post_id
    traversed = []
    while true do
      raise 'Circular reference in post' if traversed.include? post_id
      traversed.push post_id
      next_post_id = $db[:posts].where(:id => post_id).first[:in_reply_to]
      return post_id if next_post_id.nil?
      post_id = next_post_id
    end
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

    # Set alias to 'Anonymous'
    $db[:aliases].insert :user => hash, :alias => 'Anonymous'

    @user = hash
    @alias = 'Anonymous'
  else
    # Attempt to authenticate user
    row = $db[:auth].where(:hash => request.cookies['h']).first

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'No such user with that hash.'}) \
      if row.nil?

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'Provided hash does not match server generated.'}) \
      if Digest::MD5.hexdigest("#{[request.cookies['s']].pack('H*')}#{[row[:server_secret]].pack('H*')}") != request.cookies['h']

    # Set @user, @alias
    @user = request.cookies['h']
    @alias = $db[:aliases].where(:user => @user).first[:alias]
  end
end

get '/' do
  erb :global do
    'test'
  end
end

get '/prefs/' do
  erb :prefs, :layout => :global
end

post '/prefs/' do
  case params[:action]
  when 'change_alias'
    $db[:aliases].where(:user => @user).update(:alias => params[:new_alias])
  end

  redirect to('/prefs/')
end

get '/new_post/' do
  erb :new_post, :layout => :global
end

post '/new_post/' do
  $db[:posts].insert :author => @user, :content => params[:content], :date => Time.now.to_i,
                     :tags => (params[:tags] or ''), :in_reply_to => params[:reply]

  # Redirect to (new) thread
  if params[:reply].nil? # This a new thread, find the post ID of thread OP and go to it
    redirect to("/t/#{$db[:posts].where(:author => @user).to_a[-1][:id]}/")
  else # This is a reply to a thread, go to OP in thread
    redirect to("/t/#{find_op params[:reply]}/")
  end
end

get '/t/:id/' do
  erb :thread, :layout => :global
end
