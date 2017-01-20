class ReviewRating < ActiveRecord::Base
  belongs_to :review
  belongs_to :user

  validates :rating, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2}
  
  def self.deliver_ratings_lti(rating_id)
    rating = ReviewRating.find(rating_id)
    reviewer = rating.review.user
    exercise = rating.review.submission.exercise
    
    reviews_of_reviewer = Review.where(submission_id: exercise.submission_ids, user_id: reviewer.id).all
    lti_launch_params = nil
    lti_launch_params_timestamp = nil
    rating_sum = 0
    
    # Calculate mean of ratings for one review (multiple group members rate one review)
    reviews_of_reviewer.each do |review|
      if !lti_launch_params || review.created_at > lti_launch_params_timestamp
        lti_launch_params = review.lti_launch_params
        lti_launch_params_timestamp = review.created_at
      end
      
      unless review.review_ratings.empty?
        # Calculate mean
        rating_sum += review.review_ratings.inject(0){ |sum, rating| sum + rating.rating }.to_f / review.review_ratings.size
      end
    end
  
    
    # Send grades via LTI
    params = JSON.parse(lti_launch_params)
    consumer_key = params['oauth_consumer_key']
    secret = OAUTH_CREDS[consumer_key]
    provider = IMS::LTI::ToolProvider.new(consumer_key, secret, params)
    
    response = provider.post_replace_result!(rating_sum)
    
    if response.unsupported?
      logger.warn "Failed to send review ratings for user #{reviewer.id} via LTI (unspported)."
    else
      logger.warn "Failed to send review ratings for user #{reviewer.id} via LTI."
    end
  end
  
end
