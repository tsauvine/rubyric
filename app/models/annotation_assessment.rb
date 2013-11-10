# encoding: UTF-8
class AnnotationAssessment < Review

  def update_from_json(id, params)
    Review.transaction do
      review = Review.find(id)
      commands = JSON.parse(params['payload'])
      assessment = JSON.parse(review.payload || '{"annotations": []}')
      logger.debug "== Current review =="
      logger.debug assessment
      
      annotations_to_create = []  # array of hashes
      annotations_to_delete = {}  # id => true
      
      modified_content = {}    # id => 'content'
      modified_grade = {}      # id => grade
      modified_position = {}   # id => {x: , y:}
      
      annotations = []
      
      
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
        end
      end
      
      # Do deletions and modifications. Find next free id.
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
      
      logger.debug "== New review =="
      logger.debug annotations
      assessment['annotations'] = annotations
      
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
