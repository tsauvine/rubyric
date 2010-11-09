require 'test_helper'

class CourseInstancesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:course_instances)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_course_instance
    assert_difference('CourseInstance.count') do
      post :create, :course_instance => { }
    end

    assert_redirected_to course_instance_path(assigns(:course_instance))
  end

  def test_should_show_course_instance
    get :show, :id => course_instances(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => course_instances(:one).id
    assert_response :success
  end

  def test_should_update_course_instance
    put :update, :id => course_instances(:one).id, :course_instance => { }
    assert_redirected_to course_instance_path(assigns(:course_instance))
  end

  def test_should_destroy_course_instance
    assert_difference('CourseInstance.count', -1) do
      delete :destroy, :id => course_instances(:one).id
    end

    assert_redirected_to course_instances_path
  end
end
