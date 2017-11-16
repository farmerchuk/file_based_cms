# cms.rb

require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, "secret"
end

helpers do

end

before do

end

# Routes

get "/" do
  "Getting started."
end
