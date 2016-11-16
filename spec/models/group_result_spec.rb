require "rails_helper"

describe Group do
  describe '#result' do
    
    before do
      @exercise = Exercise.create(name: 'Test exercise', groupsizemin: 1, groupsizemax: 3)
      @another_exercise = Exercise.create(name: 'Another exercise', groupsizemin: 1, groupsizemax: 3)
      @group = Group.new()
      
      @group.group_members = [
        GroupMember.new(:studentnumber => '12345'),
        GroupMember.new(:studentnumber => '23456')
        ]
    end
    
    context 'when no submissions' do
      before do
        # Submissions to another exercise should not interfere
        another_submission = Submission.new(:group => @group, :exercise => @another_exercise)
        another_submission.reviews = [Review.new(:status => 'finished', :grade => '1')]
        @group.submissions = [another_submission]
      end
      
      it 'returns nil grade in mean mode' do
        result = @group.result(@exercise, :mean)
        expect(result[:grade]).to eq nil
        expect(result[:no_submissions]).to eq true
        expect(result[:not_enough_reviews]).to be_falsey
      end
      
      it 'returns nil grade in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq nil
        expect(result[:no_submissions]).to eq true
        expect(result[:not_enough_reviews]).to be_falsey
      end
    end
    
    
    context 'when no reviews' do
      before do
        @group.submissions = [Submission.new(:group => @group, :exercise => @exercise)]
      end
      
      it 'returns nil grade in mean mode' do
        result = @group.result(@exercise, :mean)
        expect(result[:grade]).to eq nil
        expect(result[:no_submissions]).to be_falsey
        expect(result[:not_enough_reviews]).to eq true
      end
      
      it 'returns nil grade in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq nil
        expect(result[:no_submissions]).to be_falsey
        expect(result[:not_enough_reviews]).to eq true
      end
    end
    
    
    context 'when one review' do
      before do
        submission = Submission.new(:group => @group, :exercise => @exercise)
        submission.reviews = [
          Review.new(:status => 'finished', :grade => '5'),
          Review.new(:status => '', :grade => '100'),
          Review.new(:status => 'started', :grade => '100')
        ]
        @group.submissions = [submission]
      end
      
      it 'returns correct result in mean mode' do
        result = @group.result(@exercise, :mean)
        expect(result[:grade]).to eq '5'
      end
      
      it 'returns correct result in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq '5'
      end
      
      it 'returns correct result in min mode' do
        result = @group.result(@exercise, :min)
        expect(result[:grade]).to eq '5'
      end
      
      it 'returns correct result in max mode' do
        result = @group.result(@exercise, :max)
        expect(result[:grade]).to eq '5'
      end
    end
    
    
    context 'when multiple reviews' do
      before do
        # Submissions to another exercise should not interfere
        another_submission = Submission.new(:group => @group, :exercise => @another_exercise)
        another_submission.reviews = [
          Review.new(:status => 'finished', :grade => '100'),
          ]
        
        submission = Submission.new(:group => @group, :exercise => @exercise)
        submission.reviews = [
          Review.new(:status => 'finished', :grade => '3'),
          Review.new(:status => 'finished', :grade => '2'),
          Review.new(:status => 'finished', :grade => '6'),
          Review.new(:status => 'started', :grade => '100'),  # Started review should not affect results
          Review.new(:status => 'finished', :grade => '4'),
          Review.new(:status => 'finished', :grade => '1'),
          Review.new(:status => 'finished', :grade => '5')
          ]
        @group.submissions = [another_submission, submission]
      end
      
      it 'returns correct result in mean mode' do
        result = @group.result(@exercise, :mean)
        expect(result[:grade]).to eq '3.5'
        expect(result[:not_enough_reviews]).to be_falsey
      end
      
      it 'returns correct result in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq '3'
        expect(result[:not_enough_reviews]).to be_falsey
      end
      
      it 'returns correct result in min mode' do
        result = @group.result(@exercise, :min)
        expect(result[:grade]).to eq '1'
        expect(result[:not_enough_reviews]).to be_falsey
      end
      
      it 'returns correct result in max mode' do
        result = @group.result(@exercise, :max)
        expect(result[:grade]).to eq '6'
        expect(result[:not_enough_reviews]).to be_falsey
      end
      
      it 'returns correct result in n_best mean mode' do
        result = @group.result(@exercise, :mean, 2)
        expect(result[:grade]).to eq '5.5'
      end
      
      it 'returns correct result in n_worst mean mode' do
        result = @group.result(@exercise, :mean, -2)
        expect(result[:grade]).to eq '1.5'
      end
      
      it 'returns correct result in n_worst median mode' do
        result = @group.result(@exercise, :median, -3)
        expect(result[:grade]).to eq '2'
      end
      
      it 'returns correct result in n_best min mode' do
        result = @group.result(@exercise, :min, 2)
        expect(result[:grade]).to eq '5'
      end
      
      it 'returns correct result in n_best max mode' do
        result = @group.result(@exercise, :max, 2)
        expect(result[:grade]).to eq '6'
      end
      
      it 'returns correct result in n_worst min mode' do
        result = @group.result(@exercise, :min, -2)
        expect(result[:grade]).to eq '1'
      end
      
      it 'returns correct result in n_worst max mode' do
        result = @group.result(@exercise, :max, -2)
        expect(result[:grade]).to eq '2'
      end
      
      it 'returns warning if not enough reviews for n_best' do
        result = @group.result(@exercise, :mean, 7)
        expect(result[:grade]).to eq '3.5'
        expect(result[:not_enough_reviews]).to eq true
      end
    end
    
    context 'with odd number of reviews' do
      before do
        submission = Submission.new(:group => @group, :exercise => @exercise)
        submission.reviews = [
          Review.new(:status => 'finished', :grade => '1'),
          Review.new(:status => 'finished', :grade => '13'),
          Review.new(:status => 'finished', :grade => '2'),
          Review.new(:status => 'finished', :grade => '24'),
          Review.new(:status => 'finished', :grade => '5')
          ]
        @group.submissions = [submission]
      end
      
      it 'returns correct result in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq '5'
      end
    end
    
    context 'with non-sortable grades' do
      before do
        submission = Submission.new(:group => @group, :exercise => @exercise)
        submission.reviews = [
          Review.new(:status => 'finished', :grade => '2'),
          Review.new(:status => 'finished', :grade => 'Failed'),
          Review.new(:status => 'finished', :grade => '3'),
          Review.new(:status => 'finished', :grade => '4')
          ]
        @group.submissions = [submission]
      end
      
      it 'returns correct result in mean mode' do
        result = @group.result(@exercise, :mean)
        expect(result[:grade]).to eq nil
        expect(result[:not_enough_reviews]).to be_falsey
        expect(result[:errors]).not_to be_empty
      end
      
      it 'returns correct result in median mode' do
        result = @group.result(@exercise, :median)
        expect(result[:grade]).to eq nil
        expect(result[:not_enough_reviews]).to be_falsey
        expect(result[:errors]).not_to be_empty
      end
    end
  end
end
