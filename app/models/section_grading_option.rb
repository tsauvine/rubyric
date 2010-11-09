class SectionGradingOption < ActiveRecord::Base
  belongs_to :section
  acts_as_list :scope => :section

  has_many :feedbacks, {:dependent => :nullify}
end
