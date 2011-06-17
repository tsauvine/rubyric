class GroupInvitation < ActiveRecord::Base
  belongs_to :group
  belongs_to :exercise
end
