class RubricsController < ApplicationController
  
  layout 'wide'
  
  def edit
    @exercise = Exercise.find(params[:exercise_id], :include =>
      {:categories =>
        {:sections =>
          [{:items => [:phrases, :item_grading_options]}, :section_grading_options]
        }
      })
    load_course
    
    if params[:section]
      @section = Section.find(params[:section], :include => {:items => :phrases})
    else
      @section = @exercise.categories.first.sections.first
    end
    
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)
  end

  def preview
    @review = Review.new
    @exercise = Exercise.find(params[:id])
    load_course

    # Authorization
    return access_denied unless @course.has_teacher(current_user) || is_admin?(current_user)

    if params[:section]
      @section = Section.find(params[:section], :include => {:items => :phrases})
    else
      @section = @exercise.categories.first.sections.first
    end

    # TODO: unless @section...

    @feedback = Feedback.new
  end

  def rename_category
    category = Category.find(params[:id])
    category.name = params[:value]
    category.save
    render :text => category.name
  end

  def set_category_weight
    category = Category.find(params[:id])
    category.weight = params[:value].to_f
    category.save
    render :text => category.weight
  end

  def rename_section
    section = Section.find(params[:id])
    section.name = params[:value]
    section.save
    render :text => section.name
  end

  def set_section_weight
    section = Section.find(params[:id])
    section.weight = params[:value].to_f
    section.save
    render :text => section.weight
  end

  def rename_item
    item = Item.find(params[:id])
    item.name = params[:value]
    item.save
    render :text => item.name
  end

  def rename_phrase
    phrase = Phrase.find(params[:id])
    phrase.content = params[:value]
    phrase.save
    render :text => CGI.escapeHTML(phrase.content).gsub(/\n|\r/, '<br />')
  end

  def get_unformatted_phrase
    phrase = Phrase.find(params[:id])
    render :text => phrase.content
  end

  def rename_item_grading_option
    grading_option = ItemGradingOption.find(params[:id])
    grading_option.text = params[:value]
    grading_option.save
    render :text => grading_option.text
  end

  def rename_section_grading_option
    grading_option = SectionGradingOption.find(params[:id])
    grading_option.text = params[:value]
    grading_option.save
    render :text => grading_option.text
  end

  def rename_section_grading_value
    grading_option = SectionGradingOption.find(params[:id])
    grading_option.points = params[:value]
    grading_option.save
    render :text => grading_option.points
  end

  def update_final_comment
    exercise = Exercise.find(params[:id])
    exercise.finalcomment = params[:value]
    exercise.save
    render :text => exercise.finalcomment
  end

  def update_positive_caption
    exercise = Exercise.find(params[:id])
    exercise.positive_caption = params[:value]
    exercise.save
    render :text => exercise.positive_caption
  end

  def update_negative_caption
    exercise = Exercise.find(params[:id])
    exercise.negative_caption = params[:value]
    exercise.save
    render :text => exercise.negative_caption
  end

  def update_neutral_caption
    exercise = Exercise.find(params[:id])
    exercise.neutral_caption = params[:value]
    exercise.save
    render :text => exercise.neutral_caption
  end

  def new_category
    exercise = Exercise.find(params[:eid])
    category = Category.new
    category.exercise_id = params[:eid]
    category.name = 'New part'
    category.position = exercise.categories.last.position + 1 unless exercise.categories.empty?
    category.save

    render :partial => 'category', :object => category
  end

  def new_section
    category = Category.find(params[:cid])
    section = Section.new
    section.category_id = params[:cid]
    section.name = 'New section'

    section.position = category.sections.last.position + 1 unless category.sections.empty?
    category.sections << section

    render :partial => 'section', :object => section
  end

  def new_item
    section = Section.find(params[:sid])
    item = Item.new
    item.section_id = params[:sid]
    item.name = 'New item'
    item.position = section.items.last.position + 1 unless section.items.empty?
    item.save

    render :partial => 'item', :object => item
  end

  def new_phrase
    item = Item.find(params[:iid])
    phrase = Phrase.new({:content => 'New phrase', :feedbacktype => 'Good'})
    phrase.item_id = params[:iid]
    phrase.position = item.phrases.last.position + 1 unless item.phrases.empty?
    phrase.save

    render :partial => 'phrase', :object => phrase
  end

  def new_phrases
    item = Item.find(params[:iid])

    if item.phrases.empty?
      position_counter = 1
    else
      position_counter = item.phrases.last.position + 1
    end

    if params[:text]
      params[:text].each do |key,value|
        item.phrases << Phrase.new({:item_id => params[:iid], :content => value, :feedbacktype => params[:type][key], :position => position_counter})

        position_counter += 1
      end
    end

    render :partial => 'phrase', :collection => item.phrases
  end

  def destroy_category
    Category.find(params[:id]).destroy

    render :update do |page|
      page.remove "categoryElement#{params[:id]}"
    end
  end

  def destroy_section
    Section.find(params[:id]).destroy

    render :update do |page|
      page.remove "sectionElement#{params[:id]}"
    end
  end

  def destroy_item
    Item.find(params[:id]).destroy

    render :update do |page|
      page.remove "itemElement#{params[:id]}"
    end
  end

  def destroy_phrase
    Phrase.find(params[:id]).destroy

    render :update do |page|
      page.remove "phraseElement#{params[:id]}"
    end
  end

  def move_category
    category = Category.find(params[:cid])
    category.move(params[:offset].to_i)
    render :partial => 'rubric', :object => category.exercise.reload
  end

  def move_section
    section = Section.find(params[:sid])
    section.move(params[:offset].to_i)
    render :partial => 'section', :collection => section.category.sections.reload
  end

  def move_item
    item = Item.find(params[:iid])
    item.move(params[:offset].to_i)
    render :partial => 'item', :collection => item.section.items.reload
  end

  def move_phrase
    phrase = Phrase.find(params[:pid])
    phrase.move(params[:offset].to_i)
    render :partial => 'phrase', :collection => phrase.item.phrases.reload
  end

  def set_phrase_type
    #logger.info("Select test: #{params[:id]} = #{params[:type]}")

    phrase = Phrase.find(params[:pid])
    phrase.feedbacktype = params[:type]
    phrase.save

    render :text => 'OK'
  end

  def new_item_grading_option
    item = Item.find(params[:iid])
    text = params[:text] || 'OK'

    grading_option = ItemGradingOption.new({:item_id => params[:iid], :text => text})
    item.item_grading_options << grading_option

    render :partial => 'item_grade', :object => grading_option
  end

  def new_item_grading_options
    # Check that some parameters were given
    unless params[:text]
      render :text => ''
      return
    end

    # Add new grading options
    item = Item.find(params[:iid])
    params[:text].each do |key,text|
      grading_option = ItemGradingOption.new({:item_id => params[:iid], :text => text})
      item.item_grading_options << grading_option
    end

    # Render the altered collection
    render :partial => 'item_grade', :collection => item.item_grading_options
  end

  def destroy_item_grading_option
    ItemGradingOption.find(params[:id]).destroy

    render :update do |page|
      page.remove "itemGradeElement#{params[:id]}"
    end
  end

  def move_item_grading_option
    grading_option = ItemGradingOption.find(params[:gid])

    if (params[:offset].to_i < 0)
      grading_option.move_higher
    else
      grading_option.move_lower
    end

    render :partial => 'item_grade', :collection => grading_option.item.item_grading_options
  end

  def new_section_grading_option
    section = Section.find(params[:sid])

    grading_option = SectionGradingOption.new({:section_id => params[:sid], :text => 'OK', :points => 0})
    section.section_grading_options << grading_option

    render :partial => 'section_grade', :object => grading_option
  end

  def new_section_grading_options
    section = Section.find(params[:sid])

    if params[:text]
      params[:text].each do |key,value|
        grading_option = SectionGradingOption.new({:section_id => params[:iid], :text => value, :points => params[:points][key]})
        section.section_grading_options << grading_option
      end
    end

    # Render the altered collection
    render :partial => 'section_grade', :collection => section.section_grading_options
  end

  def move_section_grading_option
    grading_option = SectionGradingOption.find(params[:gid])

    if (params[:offset].to_i < 0)
      grading_option.move_higher
    else
      grading_option.move_lower
    end

    render :partial => 'section_grade', :collection => grading_option.section.section_grading_options
  end

  def destroy_section_grading_option
    SectionGradingOption.find(params[:id]).destroy

    render :update do |page|
      page.remove "sectionGradeElement#{params[:id]}"
    end
  end

  def set_feedbackgrouping
    logger.info('Set feedback grouping')

    exercise = Exercise.find(params[:eid])
    exercise.feedbackgrouping = params[:type]
    exercise.save

    render :text => 'OK'
  end

  # Ajax, updates the general settings section of rubric
  def update_settings
    @exercise = Exercise.find(params[:id])
    load_course

    unless @course.has_teacher(current_user) || is_admin?(current_user)
      head :forbidden
      return
    end

    if @exercise.update_attributes(params[:exercise])
      flash[:success] = 'Settings updated'
      render :partial => 'settings' #, :locals => { :message => 'Settings updated' }
    else
      flash[:error] = 'Failed to update settings'
      render :partial => 'settings'
    end
  end
end
