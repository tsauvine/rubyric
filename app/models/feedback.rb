class Feedback < ActiveRecord::Base
  belongs_to :review
  belongs_to :section

  has_and_belongs_to_many :item_grades, {:class_name => 'ItemGradingOption', :join_table => 'item_grades'}
  belongs_to :section_grading_option

  # status: [empty], started, finished
end
