class Group < ActiveRecord::Base
  belongs_to :exercise
  belongs_to :course_instance

  has_many :group_members, :dependent => :destroy
  has_many :users, :through => :group_members
  
  has_many :submissions, {:order => 'created_at DESC', :dependent => :destroy}

  has_many :group_reviewers, :dependent => :destroy
  has_many :reviewers, :through => :group_reviewers, :source => :user, :class_name => 'User'

  #accepts_nested_attributes_for :group_members, :reject_if => proc { |attributes| attributes['email'].blank? }
  validate :require_group_members
  before_create :generate_token
  
  attr_accessor :url  # Needed for JSON serialization

  def require_group_members
    errors.add(:base, "Group cannot be empty") if self.group_members.empty?
  end
  
  # Generates a unique token
  def generate_token
    begin
      self.access_token = Digest::SHA1.hexdigest([Time.now, rand].join)
    end while Group.exists?(:access_token => self.access_token)
  end
  
  def has_member?(user)
    user && users.include?(user)
  end
  
  def has_reviewer?(user)
    user && reviewers.include?(user)
  end

  def add_member(user)
    self.users << user unless self.users.include?(user)
    self.course_instance.students << user unless self.course_instance.students.include?(user)
  end
  

  # members: array of GroupMembers
  def add_members(members, exercise)
    members.each do |member|
      user = User.find_by_email(member.email)

      if user
        member.user = user
        member.save
        self.course_instance.students << user unless self.course_instance.students.include?(user)
      else
        member.save
        GroupMember.delay.send_invitation(member.id, exercise.id)
      end
    end
  end

end
