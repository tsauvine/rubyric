require "rails_helper"

describe Group do
  describe '#result' do
    before do
      @exercise = Exercise.new()
      @group = Group.new()
      
      @group.group_members = [
        GroupMember.new(:studentnumber => '12345'),
        GroupMember.new(:studentnumber => '23456')
        ]
      
      submission = Submission.new(:group => @group, :exercise => @exercise)
      submission.reviews = [
        Review.new(:status => 'finished', :grade => 1),
        Review.new(:status => 'finished', :grade => 2),
        Review.new(:status => 'finished', :grade => 3)
        ]
      @group.submissions = [submission]
    end
    
    it 'returns results' do
      result = @group.result(@exercise, :mean)

      # {
      #   grade: ,
      #   reviews: [Review, ...],
      #   not_enough_reviews: true / false or missing
      #   errors: [String, ...]
      # }
      
      expect(result[:grade]).to eq 2
    end
  end
end
