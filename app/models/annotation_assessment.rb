# encoding: UTF-8
class AnnotationAssessment < Review

  def update_from_json(id, params)
    Review.transaction do
      review = Review.find(id)
      review.grade = params['grade']
      review.status = params['status']
      
      commands = JSON.parse(params['payload'])
      assessment = JSON.parse(review.payload || '{"annotations": [], "pages": []}')
      annotations = []
      pages_by_id = {}
      logger.debug "== Current review =="
      logger.debug assessment
      
      annotations_to_create = []  # array of hashes
      annotations_to_delete = {}  # id => true
      
      modified_content = {}       # id => 'content'
      modified_grade = {}         # id => grade
      modified_position = {}      # id => {x: , y:}
      
      new_page_grades = {}        # page_id => grade
      new_phrase_selections = []  # [{page_id: , criterion_id: , phrase_id: }]
      
      # Load commands
      commands.each do |command|
        case command['command']
        when 'create_annotation'
          annotations_to_create << command
        when 'delete_annotation'
          annotations_to_delete[command['id']] = true
        when 'modify_annotation'
          id = command['id']
          modified_content[id] = command['content'] if command['content']
          modified_grade[id] = command['grade'] if command['grade']
          modified_position[id] = command['page_position'] if command['page_position']
        when 'set_page_grade'
          new_page_grades[command['page_id']] = command['grade']
        when 'set_selected_phrase'
          new_phrase_selections << {'page_id' => command['page_id'], 'criterion_id' => command['criterion_id'], 'phrase_id' => command['phrase_id']}
        end
      end
      
      # Index pages
      assessment['pages'].each do |page|
        page_id = page['id']
        pages_by_id[page_id] = page unless page_id.nil?
      end
      
      # Set new page grades
      new_page_grades.each do |page_id, new_grade|
        page = pages_by_id[page_id]
        unless page
          page = {'id' => page_id, 'criteria' => []}
          pages_by_id[page_id] = page
          assessment['pages'] << page
        end
        
        page['grade'] = new_grade
      end
      
      # Set selected phrases
      new_phrase_selections.each do |new_selection|
        page_id = new_selection['page_id']
        page = pages_by_id[page_id]
        unless page
          page = {'id' => page_id, 'criteria' => []}
          pages_by_id[page_id] = page
          assessment['pages'] << page
        end
        
        criterion_id = new_selection['criterion_id']
        criterion = page['criteria'].select {|criterion| criterion['criterion_id'] == criterion_id}.first
        
        if criterion
          criterion['selected_phrase_id'] = new_selection['phrase_id']
        else
          criterion = {'criterion_id' => criterion_id, 'selected_phrase_id' => new_selection['phrase_id']}
          page['criteria'] << criterion
        end
      end
      
      # Do deletions and modifications of annotations. Find next free id.
      max_id = -1
      assessment['annotations'].each do |annotation|
        id = annotation['id']
        max_id = id if id > max_id
        
        # Don't keep this annotation if it's marked for deletion
        next if annotations_to_delete[id]
        
        # Do modifications
        annotation['content'] = modified_content[id] if modified_content[id]
        annotation['grade'] = modified_grade[id] if modified_grade[id]
        annotation['page_position'] = modified_position[id] if modified_position[id]
        
        # Keep this annotation
        annotations << annotation
      end
      
      # Create annotations
      annotations_to_create.each do |command|
        new_annotation = {
          'id' => max_id + 1,
          'submission_page_number' => command['submission_page_number'],
          'phrase_id' => command['phrase_id'],
          'content' => command['content'],
          'grade' => command['grade'],
          'page_position' => command['page_position']
        }
        
        annotations << new_annotation
        max_id += 1
      end
      
      assessment['annotations'] = annotations
      #assessment['pages'] = pages.values
      
      # Calculate grade
      # TODO: if grading_mode == 'sum'
      
      
      
      logger.debug "== New review =="
      logger.debug assessment
      
      # Serialize
      review.payload = assessment.to_json()
      review.save()
    end
  end
  
  
  def self.deliver_reviews(review_ids)
    errors = []
    
    AnnotationAssessment.where(:id => review_ids).find_each do |assessment|
      begin
        FeedbackMailer.annotation(assessment).deliver
      rescue Exception => e
        logger.error e
        errors << e
        assessment.status = 'finished'
        assessment.save
      end
    end
    
    # Send delivery errors to teacher
    FeedbackMailer.delivery_errors(errors).deliver unless errors.empty?
  end
  
end
