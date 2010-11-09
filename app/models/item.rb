class Item < ActiveRecord::Base
  belongs_to :section
  has_many :phrases, {:dependent => :destroy, :order => 'position'}
  has_many :item_grading_options, {:dependent => :destroy, :order => 'position'}

  def move(offset)
    index = section.items.index(self)
    return if index + offset < 0 || index + offset >= section.items.size

    other = section.items[index + offset]
    swap_indices(self, other)
  end

  def swap_indices(a, b)
    return unless a and b

    a.position, b.position = b.position, a.position
    a.save
    b.save
  end

end
