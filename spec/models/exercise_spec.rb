require "rails_helper"

describe Exercise, '#results' do
  def create_reviews
    @exercise = Exercise.new()
    
    group = Group.new()
    group.group_members = [
      GroupMember.new(:studentnumber => '12345'),
      GroupMember.new(:studentnumber => '23456')
      ]
    
    submission = Submission.new(:group => group)
    submission.reviews = [
      Review.new(:status => 'finished', :grade => 1),
      Review.new(:status => 'finished', :grade => 2),
      Review.new(:status => 'finished', :grade => 3)
      ]
    
    @groups = [
      group
    ]
  end
  
  
  it 'returns results' do
    create_reviews()
    result = @exercise.results(@groups)

    expect(true).to eq true
  end
end
