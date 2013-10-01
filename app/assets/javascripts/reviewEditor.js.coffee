#= require knockout-2.2.1
#= require bootstrap

class Page
  constructor: (@rubricEditor) ->
    @criteria = ko.observableArray()
    @criteriaById = {}          # id => Criterion
    @grade = ko.observable()
    @phrasesHidden = ko.observable(false)

    @feedback = []              # [{id: category_id, value: ko.observable('feedback')}]
    @feedbackByCategory = {}    # category_id => {<see above>}

    @averageGrade = ko.computed((-> 
      grades = []
      for criterion in @criteria()
        grades.push(criterion.grade()) if criterion.gradeRequired
      
      return @rubricEditor.calculateGrade(grades)
    ), this)
    
    @finished = ko.computed((->
      for criterion in @criteria()
        return false if criterion.gradeRequired && !criterion.grade()
        
      return true
      ), this)

  load_rubric: (data) ->
    @name = data['name']
    @id = data['id']
    
    # Prepare feedback containers
    for category in @rubricEditor.feedbackCategories
      feedbackHeight = Math.floor(100.0 / @rubricEditor.feedbackCategories.length) + "%"
      feedback = {
        id: category.id,
        title: category.name,
        value: ko.observable(''),
        height: feedbackHeight
      }
      @feedback.push(feedback)
      @feedbackByCategory[category.id] = feedback

    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this, criterion_data)
      @criteria.push(criterion)
      @criteriaById[criterion.id] = criterion
  
  
  load_review: (data) ->
    if data['feedback'] && data['feedback'].length > 0
      for feedback_data in data['feedback']
        feedback = @feedbackByCategory[feedback_data['category_id']] || @feedback[0]
        feedback.value(feedback.value() + feedback_data['text']) if feedback
    
    if data['criteria']
      for criterion_data in data['criteria']
        criterion = @criteriaById[criterion_data['criterion_id']]
        continue unless criterion
        
        phrase = criterion.phrasesById[criterion_data['selected_phrase_id']]
        continue unless phrase
        
        criterion.selectedPhrase(phrase)
        phrase.highlighted(true)
    
    @grade(data['grade']) if data['grade']?

  to_json: ->
    feedback = @feedback.map (fb) -> { category_id: fb.id, text: fb.value() }
    
    criteria = []
    for criterion in @criteria()
      c = criterion.to_json()
      criteria.push(c) if c
    
    json = {
      id: @id,
      feedback: feedback,
      criteria: criteria,
      grade: @grade()
    }

    return json

  addPhrase: (content, categoryId) ->
    return if @rubricEditor.finalizing()
    feedback = @feedbackByCategory[categoryId || 0] || @feedback[0]
    feedback.value(feedback.value() + content + "\n") if feedback
  
  cancelFinalize: (data, event) ->
    @rubricEditor.cancelFinalize()
    event.preventDefault()
    return false
  
  togglePhraseVisibility: ->
    @phrasesHidden(!@phrasesHidden())


class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @id = data['id']
    @name = data['name']
    @phrases = []
    @phrasesById = {} # id => Phrase
    @selectedPhrase = ko.observable()  # Phrase object which is selected as the grade
    @gradeRequired = false

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, @page, this)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)
      @phrasesById[phrase.id] = phrase

  setGrade: (phrase) ->
    return if @rubricEditor.finalizing()
    
    # Unhilight previous
    previousPhrase = @selectedPhrase()
    previousPhrase.highlighted(false) if previousPhrase
    
    # Hilight new
    @selectedPhrase(phrase)
    phrase.highlighted(true) if phrase
  
  to_json: ->
    return unless @selectedPhrase()
    
    return { criterion_id: @id, selected_phrase_id: @selectedPhrase().id }

  grade: ->
    return @selectedPhrase().grade if @selectedPhrase()


class Phrase
  constructor: (@rubricEditor, @page, @criterion) ->
    @highlighted = ko.observable(false)

  load_json: (data) ->
    @id = data['id']
    @categoryId = data['category']
    @grade = data['grade']
    @content = data['text']
    @escaped_content = @content.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
    
    @criterion.gradeRequired = true if @grade?

  clickPhrase: ->
    @page.addPhrase(@content, @categoryId)
    this.clickGrade()

  clickGrade: ->
    @criterion.setGrade(this) if @grade


class @ReviewEditor

  constructor: () ->
    @paused = ko.observable(true)
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
    

  #
  # Loads the rubric by AJAX
  #
  loadRubric: (url, callback) ->
    $.ajax
      type: 'GET'
      url: url
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        this.parseRubric(data)
        callback()

  #
  # Loads the review
  #
  loadReview: () ->
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
    
    @gradingMode = data['gradingMode'] || 'no'

    # Parse feedback categories
    raw_categories = data['feedbackCategories']
    if !raw_categories? || raw_categories.length < 1
      # Make sure that there is at least one category
      raw_categories = [{id: 0, name: ''}]
    
    # Don't use category title if only one category is present
    raw_categories[0].name = '' if raw_categories.length == 1
    
    for category in raw_categories
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

    if (@gradingMode == 'average' && @grades.length > 0) || @gradingMode == 'sum'
      @finishable = ko.computed((->
        for page in @pages
          return false unless page.finished()
        
        return true
        ) , this)
    else
      @finishable = ko.observable(true)

  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseReview: (data) ->
    if data
      for page_data in data['pages']
        page = @pagesById[page_data['id']]
        page.load_review(page_data) if page
    
    if (@gradingMode == 'average' && @grades.length > 0)
      @averageGrade = ko.computed((-> 
        grades = []
        for page in @pages
          grades.push(page.grade())
        
        return this.calculateGrade(grades)
      ), this)
    else if @gradingMode == 'sum'
      @averageGrade = ko.computed((-> 
        grades = []
        for page in @pages
          grade = page.averageGrade()
          grades.push(grade) if grade?
        
        return this.calculateGrade(grades)
      ), this)
    else
      @averageGrade = ko.observable()

    ko.applyBindings(this)
    @paused(false)
    
    # Activate the finalizing tab
    $('#tab-finish-link').tab('show') if @finalizing()
    

  # Returns the review as JSON
  encodeJSON: ->
    pages_json = @pages.map (page) -> page.to_json()
    return JSON.stringify({version: '2', pages: pages_json})

  
  # Populates the HTML-form from the model. This is called just before submitting.
  save: ->
    # Encode review as JSON
    $('#review_payload').val(this.encodeJSON())
    
    # Set grade
    if @gradingMode == 'average'
      finalGrade = @finalGrade()
    else if @gradingMode == 'sum'
      finalGrade = @averageGrade()
    else
      finalGrade = undefined
    
    if finalGrade? && finalGrade != false
      $('#review_grade').val(finalGrade)
    else
      $('#review_grade').val('')
    
    # Set status
    if @finalizing() 
      if @gradingMode == 'average' && @grades.length > 0 && !@finalGrade()?
        status = 'unfinished'
      else
        status = 'finished'
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
    grades = @pages.map (page) -> page.grade()
    grade = this.calculateGrade(grades)
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
    
  # grades: array of grade values (strings or numbers)
  calculateGrade: (grades) ->
    if @gradingMode == 'average'
      return this.calculateGradeMean(grades)
    else if @gradingMode == 'sum'
      return this.calculateGradeSum(grades)
    else
      return undefined
  
  #
  # Calculates average grade
  # If @numericGrading if true, average grade is calculated as the average value of the given grades.
  # If @numericGrading if false, average index is used instead.
  # If some grade null or undefined, undefined is returned.
  # grades: array of grade values (strings or numbers)
  #
  calculateGradeMean: (grades) ->
    return undefined if !grades? || grades.length < 1
    
    nonNumericGradesSeen = false
    gradeSum = 0.0
    indexSum = 0
    
    for grade in grades
      return undefined unless grade?
    
      index = @gradeIndexByValue[grade]
      indexSum += index
      
      # FIXME: does isNaN think that string "5" is numeric?
      if isNaN(grade)
        nonNumericGradesSeen = true
      else
        gradeSum += grade
    
    if !@numericGrading
      meanIndex = Math.round(indexSum / grades.length)
      return @grades[meanIndex]
    else if nonNumericGradesSeen
      return undefined  # Grade must be selected manually
    else
      meanGrade = Math.round(gradeSum / grades.length)
      return meanGrade
  
  #
  # Calculates sum of grades
  # grades: array of grade values (strings or numbers)
  calculateGradeSum: (grades) ->
    return undefined if !grades? || grades.length < 1
    
    gradeSum = 0.0
    
    for grade in grades
      return undefined unless grade?
      
      gradeSum += grade unless isNaN(grade)
    
    return gradeSum
  

  #
  # Callback for AJAX errors
  #
  onAjaxError: (jqXHR, textStatus, errorThrown) ->
    switch textStatus
      when 'timeout'
        alert('Server is not responding')
      else
        alert(errorThrown)
