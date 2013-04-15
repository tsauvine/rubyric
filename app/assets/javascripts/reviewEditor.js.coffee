#= require knockout-2.2.1
#= require bootstrap

class Page
  constructor: (@rubricEditor) ->
    @criteria = []
    @grade = ko.observable()

    @feedback = []              # [{id: category_id, value: ko.observable('feedback')}]
    @feedbackByCategory = {}    # category_id => {}

    @finalizing = ko.computed((->
      return @rubricEditor.finalizing()
      ), this)


  load_rubric: (data) ->
    @name = data['name']
    @id = data['id']
    
    for category in @rubricEditor.feedbackCategories
      feedback = {id: category.id, title: category.name, value: ko.observable('')}
      @feedback.push(feedback)
      @feedbackByCategory[category.id] = feedback

    for criterion_data in data['criteria']
      @criteria.push(new Criterion(@rubricEditor, this, criterion_data))
  
  load_review: (data) ->
    if data['feedback'] && data['feedback'].length > 0
      
      for feedback_data in data['feedback']
        feedback = @feedbackByCategory[feedback_data['category_id']]
        feedback.value(feedback_data['text']) if feedback
      
    @grade(data['grade']) if data['grade']?

  to_json: ->
    feedback = @feedback.map (fb) -> return { category_id: fb.id, text: fb.value() }
    
    json = {
      id: @id,
      feedback: feedback,
      grade: @grade()
    }

    return json

  addPhrase: (content, categoryId) ->
    return if @finalizing()
    feedback = @feedbackByCategory[categoryId]
    feedback.value(feedback.value() + content + "\n") if feedback
  
  cancelFinalize: (data, event) ->
    @rubricEditor.cancelFinalize()
    event.preventDefault()
    return false
    

class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @id = data['id']
    @name = data['name']
    @phrases = []

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, @page)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)



class Phrase
  constructor: (@rubricEditor, @page) ->

  load_json: (data) ->
    @id = data['id']
    @categoryId = data['category']
    @content = data['text']
    @escaped_content = @content.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')

  clickPhrase: ->
    @page.addPhrase(@content, @categoryId)


class ReviewEditor

  constructor: () ->
    @finishedText = ko.observable('')
    @finalizing = ko.observable(false)
    
    @pages = []
    @pagesById = {}
    
    @feedbackCategories = []        # [{id: 0, name: 'Strenths'}, ...]
    @feedbackCategoriesById = {}    # id -> {}
    @finalComment = ''
    
    @grades = []
    @gradeIndexByValue = {}         # gradeValue -> index (0,1,2,..). Needed for calculating average from non-numeric values.
    @numericGrading = false
    @gradingMode = 'none'
    @finalGrade = ko.observable()

    @rubric_url = $('#review-editor').data('rubric-url')
    @review_url = $('#review-editor').data('review-url')

    this.loadRubric(@rubric_url)


  #
  # Loads the rubric by AJAX
  #
  loadRubric: (url) ->
    $.ajax
      type: 'GET'
      url: url
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        this.parseRubric(data)

  #
  # Loads the review
  #
  loadReview: (url) ->
#     $.ajax
#       type: 'GET'
#       url: url
#       error: $.proxy(@onAjaxError, this)
#       dataType: 'json'
#       success: (data) =>
#         this.parseReview(data)
    
    @finishedText($('#review_feedback').val())
    
    finalGrade = $('#review_grade').val()
    @finalGrade(finalGrade) if finalGrade != ''
    
    status = $('#review_status').val()
    @finalizing(true) if status.length > 0 && status != 'started'
    
    payload = $('#review_payload').val()
    if payload.length > 0
      this.parseReview($.parseJSON(payload))
    else
      this.parseReview()

  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseRubric: (data) ->
    unless data
      alert('Rubric has not been prepared')
      return

    if data['feedbackCategories']
      for category in data['feedbackCategories']
        @feedbackCategories.push(category)
        @feedbackCategoriesById[category.id] = category

    if data['grades']
      i = 0
      for grade_data in data['grades']
        @numericGrading = true if !isNaN(grade_data)
        @grades.push(grade_data)
        @gradeIndexByValue[grade_data] = i
        i++

    for page_data in data['pages']
      page = new Page(this)
      page.load_rubric(page_data)
      @pages.push(page)
      @pagesById[page.id] = page

    @finalComment = data['finalComment']

    @finishable = ko.computed((->
      return true if @grades.length < 1
      
      for page in @pages
        return false unless page.grade()?
      
      return true
      
      ) , this)

    this.loadReview(@review_url)

  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseReview: (data) ->
    if data
      for page_data in data['pages']
        page = @pagesById[page_data['id']]
        page.load_review(page_data) if page
    
    ko.applyBindings(this)


  save: ->
    # Encode review as JSON
    pages_json = @pages.map (page) -> page.to_json()
    json_string = JSON.stringify({version: 2, pages: pages_json})
    $('#review_payload').val(json_string)
    
    # Set grade
    finalGrade = @finalGrade()
    
    if finalGrade? && finalGrade != false
      $('#review_grade').val(finalGrade)
    else
      $('#review_grade').val('')
    
    # Set status
    if @finalizing() 
      if (@finalGrade()? || @grades.length < 1)
        status = 'finished'
      else
        status = 'unfinished'
    else
      status = 'started'
    
    $('#review_status').val(status)
    
    return true
    
    # AJAX call
#     $.ajax
#       type: 'PUT',
#       url: @review_url,
#       data: {review: json_string},
#       error: $.proxy(@onAjaxError, this)
#       dataType: 'json'
#       success: (data) =>
#         window.location.href = "#{@review_url}/finish"


  cancelFinalize: ->
    @finalizing(false)

  finish: ->
    return if @finalizing()  # Ignore if already finalizing
    
    @finalizing(true)
    
    # Collect feedback texts
    this.collectFeedbackTexts()
    
    # Calculate grade
    grade = this.calculateGrade()
    @finalGrade(grade)
  
  collectFeedbackTexts: ->
    # Collect feedback from each category
    categoryTexts = {}
    for page in @pages
      for page_category in page.feedback
        categoryTexts[page_category.id] ||= ''
        val = $.trim(page_category.value())
        categoryTexts[page_category.id] += val + '\n' if val.length > 0
    
    # Combine feedback of different categories
    finalText = ''
    for category in @feedbackCategories
      categoryText = categoryTexts[category.id]
      continue if categoryText.length < 1
      
      finalText += "= #{category.name} =\n" if category.name.length > 0
      finalText += categoryText + '\n'
    
    finalText += '\n' + @finalComment if @finalComment.length > 0
    
    @finishedText(finalText)
    
    
  
  calculateGrade: ->
    nonNumericGradesSeen = false
    gradeSum = 0
    indexSum = 0
    
    for page in @pages
      grade = page.grade()
      index = @gradeIndexByValue[grade]
      
      if grade?
        # Grade is set
        indexSum += index
        
        if isNaN(grade)
          nonNumericGradesSeen = true
        else
          gradeSum += grade
      else
        # Grade not set
        return false
    
    pageCount = @pages.length
    meanGrade = Math.round(gradeSum / pageCount)
    meanIndex = Math.round(indexSum / pageCount)
    
    if !@numericGrading
      return @grades[meanIndex]
    else if nonNumericGradesSeen
      return null  # Grade must be selected manually
    else
      return meanGrade
    

  #
  # Callback for AJAX errors
  #
  onAjaxError: (jqXHR, textStatus, errorThrown) ->
    switch textStatus
      when 'timeout'
        alert('Server is not responding')
      else
        alert(errorThrown)


jQuery ->
  new ReviewEditor
