require 'sinatra'
require 'sequel'
require 'digest'

$config = { :board_name => 'board.rb',
            :db_url => 'sqlite://board.db',
            :default_userconfig => {
              'alias' => 'Unaliased',
              'subs' => ''
            } }

$db = Sequel.connect $config[:db_url]

helpers do
  def h text
    Rack::Utils.escape_html text
  end

  # Find the original poster of a thread with a post id
  def find_op post_id
    traversed = []
    while true do
      raise 'Circular reference in post' if traversed.include? post_id
      traversed.push post_id
      this_post = $db[:posts].where(:id => post_id).first
      return post_id if this_post.nil? or this_post[:in_reply_to].nil?
      post_id = this_post[:in_reply_to].to_i
    end
  end

  # Attempt to validate csrf token, error if validation fails, else, update the token.
  def validate_csrf_token
    token = $db[:userconfig].where(:user => @user, :key => 'csrf_token').first[:value]
    $db[:userconfig].where(:user => @user, :key => 'csrf_token').update(:value => Random.new.bytes(32).bytes.map {|i| i.to_s(16).rjust(2, '0')}.join)

    if params[:csrf_token].nil? or params[:csrf_token] != token
      halt erb(:error, :layout => :global, :locals => {:title => 'CSRF validation failed.', :message => 'Please go back, refresh the page and try again.'})
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

    # Set user's default config
    $config[:default_userconfig].each do |key, value|
      $db[:userconfig].insert :user => hash, :key => key, :value => value
    end

    # Set CSRF token
    $db[:userconfig].insert :user => hash, :key => 'csrf_token', :value => Random.new.bytes(32).bytes.map {|i| i.to_s(16).rjust(2, '0')}.join

    @user = hash
    @alias = $config[:default_userconfig]['alias']
  else
    # Attempt to authenticate user
    row = $db[:auth].where(:hash => request.cookies['h']).first

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'No such user with that hash.'}) \
      if row.nil?

    halt erb(:error, :layout => :global, :locals => {:title => 'Failed to confirm identity.', :message => 'Provided hash does not match server generated.'}) \
      if Digest::MD5.hexdigest("#{[request.cookies['s']].pack('H*')}#{[row[:server_secret]].pack('H*')}") != request.cookies['h']

    # Set @user, @alias
    @user = request.cookies['h']
    @alias = $db[:userconfig].where(:user => @user, :key => 'alias').first[:value]

    # Update userconfig fields
    $config[:default_userconfig].each do |key, value|
      if $db[:userconfig].where(:user => @user, :key => key).first.nil? # Install missing key
        $db[:userconfig].insert :user => @user, :key => key, :value => value
      end
    end

    # Create CSRF token if it doesn't exist
    if $db[:userconfig].where(:user => @user, :key => 'csrf_token').first.nil? # Install missing key
      $db[:userconfig].insert :user => @user, :key => 'csrf_token', :value => Random.new.bytes(32).bytes.map {|i| i.to_s(16).rjust(2, '0')}.join
    end
  end
end

get '/' do
  erb :front, :layout => :global
end

get '/all/' do
  erb :listing, :layout => :global, :locals => {:listing => $db[:posts].where(:in_reply_to => nil).reverse_order(:last_update)}
end

get '/prefs/' do
  erb :prefs, :layout => :global
end

post '/prefs/' do
  validate_csrf_token

  case params[:action]
  when 'change_alias'
    $db[:userconfig].where(:user => @user, :key => 'alias').update(:value => params[:new_alias])
  end

  redirect to('/prefs/')
end

get '/new_post/' do
  erb :new_post, :layout => :global
end

post '/new_post/' do
  validate_csrf_token

  tags = (' ' if params[:tags]).to_s + ((params[:tags] or '').split(' ').map {|t| t.gsub(/[^0-9a-z]/i, '')}.join(' ').downcase.squeeze) + (' ' if params[:tags]).to_s

  $db[:posts].insert :author => @user, :content => params[:content].gsub(/(\r\n){3,}/, "\n").gsub(/\n{3,}/, "\n"), :date => Time.now.to_i,
                     :last_update => Time.now.to_i, :tags => tags, :in_reply_to => params[:reply].nil? ? nil : params[:reply].to_i

  # Redirect to (new) thread
  if params[:reply].nil? # This a new thread, find the post ID of thread OP and go to it
    redirect to("/th/#{$db[:posts].where(:author => @user).to_a[-1][:id]}/")
  else # This is a reply to a thread, go to OP in thread
    op = find_op params[:reply].to_i
    $db[:posts].where(:id => op).update(:last_update => Time.now.to_i) # Bump OP
    redirect to("/th/#{op}/")
  end
end

get '/subs/' do
  erb :edit_subs, :layout => :global
end

post '/subs/' do
  validate_csrf_token

  case params[:action]
  when 'add'
    redirect to('/subs/') if params[:sub].gsub(/[^0-9a-z]/i, '').length < 1
    new_subs = $db[:userconfig].where(:user => @user, :key => 'subs').first[:value] + "#{params[:sub].gsub(/[^0-9a-z]/i, '')} "
    $db[:userconfig].where(:user => @user, :key => 'subs').update(:value => new_subs)
  when 'remove'
    new_subs = $db[:userconfig].where(:user => @user, :key => 'subs').first[:value].split(' ')
    new_subs.delete params[:sub]
    $db[:userconfig].where(:user => @user, :key => 'subs').update(:value => new_subs.join(' ') + (' ' if new_subs.length > 0).to_s)
  end
  redirect to('/subs/')
end

get '/th/:id/' do
  erb :thread, :layout => :global
end

get '/ta/:tags/' do
  tags = params[:tags].gsub('+', ' ').split.map {|tag| "% #{tag} %"}
  erb :listing, :layout => :global, :locals => {:listing => $db[:posts].where(:in_reply_to => nil).where(Sequel.like(:tags, *tags)).reverse_order(:last_update)}
end