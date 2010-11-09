require 'test_helper'

class ExercisesControllerTest < ActionController::TestCase
  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:exercises)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_exercise
    assert_difference('Exercise.count') do
      post :create, :exercise => { }
    end

    assert_redirected_to exercise_path(assigns(:exercise))
  end

  def test_should_show_exercise
    get :show, :id => exercises(:one).id
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => exercises(:one).id
    assert_response :success
  end

  def test_should_update_exercise
    put :update, :id => exercises(:one).id, :exercise => { }
    assert_redirected_to exercise_path(assigns(:exercise))
  end

  def test_should_destroy_exercise
    assert_difference('Exercise.count', -1) do
      delete :destroy, :id => exercises(:one).id
    end

    assert_redirected_to exercises_path
  end
end
