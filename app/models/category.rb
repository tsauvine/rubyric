class Category < ActiveRecord::Base
  belongs_to :exercise
  has_many :sections, {:dependent => :destroy, :order => 'position'}

  def move(offset)
    # move_higher, move_lower
    
    index = exercise.categories.index(self)
    return if index + offset < 0 || index + offset >= exercise.categories.size

    other = exercise.categories[index + offset]
    swap_indices(self, other)
  end

  def next_sibling
    # higher_item
    
    index = self.exercise.categories.index(self)

    if index < self.exercise.categories.size - 1
      return self.exercise.categories[index + 1]
    else
      return nil
    end
  end
  
  def swap_indices(a, b)
    return unless a and b

    a.position, b.position = b.position, a.position
    a.save
    b.save
  end

end
