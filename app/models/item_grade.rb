class ItemGrade < ActiveRecord::Base
  belongs_to :section
  belongs_to :item_grading_option
end
