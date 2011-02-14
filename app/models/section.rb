class Section < ActiveRecord::Base
  belongs_to :category
  has_many :items, {:dependent => :destroy, :order => 'position'}
  has_many :section_grading_options, {:dependent => :destroy, :order => 'position'}

  has_many :feedbacks, {:dependent => :destroy}

  def move(offset)
    index = category.sections.index(self)
    return if index + offset < 0 || index + offset >= category.sections.size

    other = category.sections[index + offset]
    swap_indices(self, other)
  end

  def next_sibling()
    index = self.category.sections.index(self)

    if index < self.category.sections.size - 1
      return self.category.sections[index + 1]
    else
      return nil
    end
  end

  # def next_sibling_or_cousin
  # TODO
  # end
  
  def swap_indices(a, b)
    return unless a and b

    a.position, b.position = b.position, a.position
    a.save
    b.save
  end

end
