class ItemGradingOption < ActiveRecord::Base
  belongs_to :item
  acts_as_list :scope => :item

  has_many :item_grades, {:dependent => :delete_all}
end
