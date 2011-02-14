require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
  fixtures :exercises, :categories
  
  should "find next sibling" do
    assert_equal categories(:category_A).next_sibling, categories(:category_B), "Next sibling of A should be B"
  end
  
  should "not find next sibling" do
    assert_nil categories(:category_C).next_sibling, "Next sibling of C should be null"
  end

  # TODO: on delete cascade
  
end
