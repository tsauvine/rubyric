class ReviewRating < ActiveRecord::Base
  belongs_to :review
  belongs_to :user
  attr_accessible :rating

  validates :rating, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
end
