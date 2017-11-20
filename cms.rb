# cms.rb

require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, "secret"
end

def files_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path('../test/files', __FILE__)
  else
    File.expand_path('../files', __FILE__)
  end
end

def load_user_credentials
  users_path =
    if ENV["RACK_ENV"] == "test"
      File.expand_path('../test/users.yml', __FILE__)
    else
      File.expand_path('../users.yml', __FILE__)
    end

  YAML.load_file(users_path)
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_name)
  file_path = File.join(files_path, file_name)
  content = File.read(file_path)
  file_ext = File.extname(file_name)

  case file_ext
  when ".md"
    erb render_markdown(content), layout: :layout
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  end
end

def valid_file(file_name)
  Dir.chdir('/users/jason/documents/projects/file_based_cms')
  file_path = files_path + "/" + file_name
  File.file?(file_path)
end

def user_signed_in?
  session[:username]
end

def redirect_unless_signed_in
  unless user_signed_in?
    session[:error] = "You must be logged in to do that."
    redirect "/"
  end
end

def valid_credentials?(username, password)
  user_credentials = load_user_credentials

  if user_credentials[username]
    bcrypt_password = BCrypt::Password.new(user_credentials[username])
    bcrypt_password == password
  else
    false
  end
end

# Routes

get "/" do
  pattern = File.join(files_path, "*")
  @files = Dir[pattern].map { |path| File.basename(path) }
  erb :files, layout: :layout
end

get "/signin" do
  erb :signin, layout: :layout
end

post "/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:success] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:error] = "Username or password incorrect."
    erb :signin, layout: :layout
  end
end

post "/signout" do
  session.delete(:username)
  session[:success] = "You were successfully signed out"
  redirect "/signin"
end

get "/new" do
  redirect_unless_signed_in

  erb :new_file, layout: :layout
end

get "/:filename" do
  file_name = params[:filename]

  if valid_file(file_name)
    load_file_content(file_name)
  else
    session[:error] = "#{file_name} does not exist."
    redirect "/"
  end
end

post "/new" do
  redirect_unless_signed_in

  file_name = params[:file_name]
  file_path = File.join(files_path, file_name)

  if file_name.empty?
    session[:error] = "Please enter a file name with extension."
    status 422
    erb :new_file, layout: :layout
  else
    File.new(file_path, "w")
    session[:success] = "#{file_name} successfully created!"
    redirect "/"
  end
end

post "/:filename" do
  redirect_unless_signed_in

  file_name = params[:filename]
  file_path = File.join(files_path, file_name)
  content = params[:content]

  File.open(file_path, "w") do |f|
    f.write(content)
  end

  session[:success] = "#{file_name} successfully updated!"
  redirect "/"
end

get "/:filename/edit" do
  redirect_unless_signed_in

  @file_name = params[:filename]
  @content = load_file_content(@file_name)
  headers["Content-Type"] = "text/html"
  erb :edit_file, layout: :layout
end

post "/:filename/delete" do
  redirect_unless_signed_in

  file_name = params[:filename]
  file_path = File.join(files_path, file_name)
  File.delete(file_path)
  session[:success] = "#{file_name} successfully deleted."
  redirect "/"
end
