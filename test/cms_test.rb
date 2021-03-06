ENV['RACK_ENV'] = 'test'

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def login_user
    get "/", {}, {"rack.session" => { username: "admin"} }
  end

  def setup
    FileUtils.mkdir_p(files_path)
    create_document "about.md", "<p>This is <em>bongos</em> indeed!</p>"
    create_document "changes.txt", "This is the changes.txt file"
  end

  def teardown
    FileUtils.rm_rf(files_path)
    post "/signout"
  end

  def create_document(name, content = "")
    File.open(File.join(files_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    login_user
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_match "about.md", last_response.body
    assert_match "changes.txt", last_response.body
  end

  def test_viewing_text_document
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_match "changes.txt", last_response.body
  end

  def test_file_does_not_exist
    login_user

    get "/somefile.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_match "does not exist", last_response.body
  end

  def test_markdown_file
    get "/about.md"
    assert_match "<p>This is <em>bongos</em> indeed!</p>\n", last_response.body
  end

  def test_editing_document
    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    get "/changes.txt/edit"
    assert_equal 200, last_response.status
    assert_match "<textarea", last_response.body
    assert_match "submit", last_response.body
  end

  def test_updating_document
    post "/changes.txt", content: "new content"
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    post "/changes.txt", content: "new content"
    assert_equal 302, last_response.status
    assert_match "changes.txt successfully updated!", session[:success]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_match "new content", last_response.body
  end

  def test_view_new_file_form
    get "/new"
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    get "/new"
    assert_equal 200, last_response.status
    assert_match "Enter the filename", last_response.body
  end

  def test_create_new_file_success
    post "/new", file_name: ""
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    post "/new", file_name: "new_file.txt"
    assert_equal 302, last_response.status
    assert_match "new_file.txt", session[:success]

    get "/"
    assert_includes last_response.body, "new_file.txt"
  end

  def test_create_new_file_missing_filename
    post "/new", file_name: ""
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    post "/new", file_name: ""
    assert_equal 422, last_response.status
    assert_match "Please enter a file name with extension.", last_response.body
  end

  def test_delete_file
    post "/changes.txt/delete"
    assert_equal 302, last_response.status
    assert_match "You must be logged in", session[:error]

    login_user

    post "/changes.txt/delete"
    assert_equal 302, last_response.status
    assert_match "changes.txt successfully deleted.", session[:success]

    get last_response["Location"]

    get "/"
    refute_match "changes.txt", session[:success]
  end

  def test_view_signin_form
    get "/signin"
    assert_equal 200, last_response.status
    assert_match "Please sign-in", last_response.body
  end

  def test_successful_signin
    post "/signin", username: "jason@gmail.com", password: "secret"
    assert_equal 302, last_response.status
    assert session[:username]
    assert session[:success] = "Welcome!"

    get last_response["Location"]
    assert_match "Currently logged in", last_response.body
  end

  def test_failed_signin
    post "/signin", username: "jason@gmail.com", password: "incorrect"
    assert_equal 422, last_response.status
    refute session[:username]
    assert_match "incorrect", last_response.body
  end

  def test_signout
    login_user

    post "/signout"

    get last_response["Location"]
    refute session[:username]
  end
end
