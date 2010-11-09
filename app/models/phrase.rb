class Phrase < ActiveRecord::Base
  belongs_to :item

  def move(offset)
    index = item.phrases.index(self)
    return if index + offset < 0 || index + offset >= item.phrases.size

    other = item.phrases[index + offset]
    swap_indices(self, other)
  end

  def swap_indices(a, b)
    return unless a and b

    a.position, b.position = b.position, a.position
    a.save
    b.save
  end

end
