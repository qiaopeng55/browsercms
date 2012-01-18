ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'action_view/test_case'
require 'mocha'
require 'redgreen'

class ActiveSupport::TestCase
  # Transactional fixtures accelerate your tests by wrapping each test method
  # in a transaction that's rolled back on completion.  This ensures that the
  # test database remains unchanged so your fixtures don't have to be reloaded
  # between every test method.  Fewer database queries means faster tests.
  #
  # Read Mike Clark's excellent walkthrough at
  #   http://clarkware.com/cgi/blosxom/2005/10/24#Rails10FastTesting
  #
  # Every Active Record database supports transactions except MyISAM tables
  # in MySQL.  Turn off transactional fixtures in this case; however, if you
  # don't care one way or the other, switching from MyISAM to InnoDB tables
  # is recommended.
  #
  # The only drawback to using transactional fixtures is when you actually 
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  require File.dirname(__FILE__) + '/test_logging'
  include TestLogging
  require File.dirname(__FILE__) + '/custom_assertions'
  include CustomAssertions

  #----- Test Macros -----------------------------------------------------------
  class << self
    def should_validate_presence_of(*fields)
      fields.each do |f|
        class_name = name.sub(/Test$/,'')
        define_method("test_validates_presence_of_#{f}") do
          model = Factory.build(class_name.underscore.to_sym, f => nil)
          assert !model.valid?
          assert_has_error_on model, f, "can't be blank"
        end
      end
    end
    def should_validate_uniqueness_of(*fields)
      fields.each do |f|
        class_name = name.sub(/Test$/,'')
        define_method("test_validates_uniqueness_of_#{f}") do
          existing_model = Factory(class_name.underscore.to_sym)
          model = Factory.build(class_name.underscore.to_sym, f => existing_model.send(f))
          assert !model.valid?
          assert_has_error_on model, f, "has already been taken"
        end
      end
    end

  end

  #----- Fixture/Data related helpers ------------------------------------------

  def admin_user
    users(:user_1)
  end

  def create_or_find_permission_named(name)
    Permission.named(name).first || Factory(:permission, :name => name)
  end

  def create_admin_user(attrs={})
    user = Factory(:user, {:login => "cmsadmin"}.merge(attrs))
    group = Factory(:group, :group_type => Factory(:group_type, :cms_access => true))
    group.permissions << create_or_find_permission_named("administrate")
    group.permissions << create_or_find_permission_named("edit_content")
    group.permissions << create_or_find_permission_named("publish_content")
    user.groups << group
    user
  end

  def file_upload_object(options)
    file = ActionController::UploadedTempfile.new(options[:original_filename])
    open(file.path, 'w') {|f| f << options[:read]}
    file.original_path = options[:original_filename]
    file.content_type = options[:content_type]
    file
  end

  def guest_group
    Group.guest || Factory(:group, :code => Group::GUEST_CODE)
  end

  def login_as(user)
    @request.session[:user_id] = user ? user.id : nil
  end

  def login_as_cms_admin
    login_as(User.first)
  end

  def mock_file(options = {})
    file_upload_object({:original_filename => "test.jpg",
      :content_type => "image/jpeg", :rewind => true,
      :size => "99", :read => "01010010101010101"}.merge(options))
  end

  # Takes a list of the names of instance variables to "reset"
  # Each instance variable will be set to a new instance
  # That is found by looking that object by id
  def reset(*args)
    args.each do |v|
      val = instance_variable_get("@#{v}")
      instance_variable_set("@#{v}", val.class.find(val.id))
    end
  end

  def root_section
    @root_section ||= Factory(:root_section)
  end

  # Fixtures add incorrect Section/Section node data. We don't want to replace fixtures AGAIN (this is handled in CMS 3.3)
  # so we can just clean it out using this method where needed to avoid test breakage.
  def remove_all_sitemap_fixtures_to_avoid_bugs
    Section.delete_all
    Page.delete_all
  end

  # Create a 'faux' sitemap which will work for tests (avoids need for fixtures)
  def given_a_site_exists
    @root = root_section
    @homepage = Factory(:public_page, :name=>"Home", :section=>@root, :path=>"/")
    @system_section = Factory(:public_page, :name=>"System", :section=>@root, :path=>"/system")
    @not_found_page = Factory(:public_page, :name=>"Not Found", :section=>@system_section, :path=>Cms::ErrorPages::NOT_FOUND_PATH)
    @access_denied_page = Factory(:public_page, :name=>"Access Denied", :section=>@system_section, :path=>Cms::ErrorPages::FORBIDDEN_PATH)
    @error_page = Factory(:public_page, :name=>"Server Error", :section=>@system_section, :path=>Cms::ErrorPages::SERVER_ERROR_PATH)
  end
end

module Cms::ControllerTestHelper
  def self.included(test_case)
    test_case.send(:include, Cms::PathHelper)
  end

  def request
    @request
  end

  def streaming_file_contents
    #The body of a streaming response is a proc
    streamer = @response.body
    assert_equal Proc, streamer.class

    #Create a dummy object for the proc to write to
    output = Object.new
    def output.write(contents)
      (@contents ||= "") << contents
    end

    #run the proc
    streamer.call(@response, output)

    #return what it wrote to the dummy object
    output.instance_variable_get("@contents")
  end
end

module Cms::IntegrationTestHelper
  def login_as(user, password = "password")
    get cms_login_url
    assert_response :success
    post cms_login_url, :login => user.login, :password => password
    assert_response :redirect
    assert flash[:notice]
  end

  def login_as_cms_admin
    login_as(User.first, "cmsadmin")
  end
end
