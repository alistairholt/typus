require "test_helper"

class Admin::DashboardControllerTest < ActionController::TestCase

  context "When authentication is http_basic" do

    setup do
      Typus.stubs(:authentication).returns(:http_basic)
    end

    should_eventually "return a 401 message when no credentials sent" do
      get :show
      assert_response 401
    end

    should_eventually "authenticate user" do
      @request.env['HTTP_AUTHORIZATION'] = 'Basic ' + Base64::encode64("admin:columbia")
      get :show
      assert_response :success
    end

  end

  context "When authentication is none" do

    setup do
      Typus.stubs(:authentication).returns(:none)
    end

    should_eventually "render dashboard" do
      get :show
      assert_response :success
    end

  end

  context "Not logged" do

    setup do
      @request.session[:typus_user_id] = nil
    end

    should "redirect to sign in when not signed in" do
      get :show
      assert_response :redirect
      assert_redirected_to new_admin_session_path
    end

  end

  should "verify_a_removed_role_cannot_sign_in" do
    typus_user = Factory(:typus_user, :role => "removed")
    @request.session[:typus_user_id] = typus_user.id

    get :show

    assert_response :redirect
    assert_redirected_to new_admin_session_path
    assert_nil @request.session[:typus_user_id]
    assert_equal "Role does no longer exists.", flash[:notice]
  end

  context "Admin is logged and gets dashboard" do

    setup do
      @typus_user = Factory(:typus_user)
      @request.session[:typus_user_id] = @typus_user.id
      get :show
    end

    teardown do
      TypusUser.delete_all
    end

    should "render dashboard" do
      assert_response :success
      assert_template "show"
    end

    should "render admin layout" do
      assert_match "layouts/admin", @controller.inspect
    end

    should "verify title" do
      assert_select "title", "Dashboard"
    end

    should "verify link to session sign out" do
      link = %(href="/admin/session")
      assert_match link, @response.body
    end

    should "verify link to edit user" do
      link = %(href="/admin/typus_users/edit/#{@request.session[:typus_user_id]})
      assert_match link, @response.body
    end

    should "verify resources have a link to new" do
      %w( typus_users posts pages assets ).each { |r| assert_match "/admin/#{r}/new", @response.body }
    end

    should "verify tableless resources do have link to new" do
      %w( statuses orders ).each { |r| assert_no_match /\/admin\/#{r}\n/, @response.body }
    end

    should "verify we can set our own partials" do
      partials = %w( _sidebar.html.erb )
      partials.each { |p| assert_match p, @response.body }
    end

  end

  context "Security" do

    setup do
      @typus_user = Factory(:typus_user)
      @request.session[:typus_user_id] = @typus_user.id
    end

    teardown do
      TypusUser.delete_all
    end

    should "block users_on_the_fly" do
      @typus_user.status = false
      @typus_user.save

      get :show

      assert_response :redirect
      assert_redirected_to new_admin_session_path
      assert_equal "Admin user has been disabled.", flash[:notice]
      assert_nil @request.session[:typus_user_id]
    end

    should "sign out user when role does not longer exist" do
      @typus_user.role = 'unexisting'
      @typus_user.save

      get :show

      assert_response :redirect
      assert_redirected_to new_admin_session_path
      assert_equal "Role does no longer exists.", flash[:notice]
      assert_nil @request.session[:typus_user_id]
    end

  end

  context "When designer is logged in" do

    setup do
      @request.session[:typus_user_id] = Factory(:typus_user, :role => "designer").id
      get :show
    end

    should "not have links to new posts" do
      assert_no_match /\/admin\/posts\/new/, @response.body
    end

    should "not have links to new typus_users" do
      assert_no_match /\/admin\/typus_users\/new/, @response.body
    end

  end

end
