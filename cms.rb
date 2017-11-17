# cms.rb

require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

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

# Routes

get "/" do
  pattern = File.join(files_path, "*")
  @files = Dir[pattern].map { |path| File.basename(path) }
  erb :files, layout: :layout
end

get "/new" do
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
  file_name = params[:file_name]
  file_path = File.join(files_path, file_name)

  if file_name.empty?
    session[:error] = "Please enter a file name with extension."
    status 422
    erb :new_file, layout: :layout
  else
    File.new(file_path, "w")
    redirect "/"
  end
end

post "/:filename" do
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
  @file_name = params[:filename]
  @content = load_file_content(@file_name)
  headers["Content-Type"] = "text/html"
  erb :edit_file, layout: :layout
end

post "/:filename/delete" do
  file_name = params[:filename]
  file_path = File.join(files_path, file_name)
  File.delete(file_path)
  session[:success] = "#{file_name} successfully deleted."
  redirect "/"
end
