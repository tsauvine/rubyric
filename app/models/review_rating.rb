class ReviewRating < ActiveRecord::Base
  belongs_to :review
  belongs_to :user

  validates :rating, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2}
end
