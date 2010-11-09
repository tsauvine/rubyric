module ReviewsHelper

  # Takes a status string (nil, started, finished, ...) and returns a css class
  # (not-started, started).
  def status_color(status)
    case status
      when nil
        'not-started'

      when 'started'
        'started'

      when 'finished'
        'finished'

      when 'mailed'
        'mailed'
    end
  end

  def status_text(status)
    case status
      when nil
        'Not started'

      when 'started'
        'Started'

      when 'finished'
        'Done'

      when 'mailed'
        'Mailed'
    end
  end


end
