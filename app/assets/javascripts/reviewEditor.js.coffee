#= require knockout-3.1.0
#= require bootstrap

class Page
  constructor: (@rubricEditor, @rubric) ->
    @nextPage = undefined
    @criteria = ko.observableArray()
    @criteriaById = {}          # id => Criterion
    @grade = ko.observable()
    @phrasesHidden = ko.observable(false)

    @feedback = []              # [{id: category_id, value: ko.observable('feedback')}]
    @feedbackByCategory = {}    # category_id => {<see above>}

    @averageGrade = ko.computed((=>
      grades = []
      for criterion in @criteria()
        grades.push(criterion.grade()) if criterion.gradeRequired || criterion.grade()?
      
      grade = @rubric.calculateGrade(grades)
      grade = @minSum if @minSum? && grade < @minSum
      grade = @maxSum if @maxSum? && grade > @maxSum
      return grade
    ), this)
    
    @finished = ko.computed((=>
      for criterion in @criteria()
        return false if criterion.gradeRequired && !criterion.grade()?
      
      return false if !@grade()? && @rubric.gradingMode == 'average' && @rubric.grades.length > 0
      
      return true
      ), this)

  load_rubric: (data) ->
    @name = data['name']
    @id = data['id']
    @minSum = data['minSum']
    @maxSum = data['maxSum']
    @instructions = data['instructions']
    
    # Prepare feedback containers
    for category in @rubric.feedbackCategories
      feedbackHeight = Math.floor(100.0 / @rubric.feedbackCategories.length) + "%"
      feedback = {
        id: category.id
        title: category.name
        value: ko.observable('')
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
  
  togglePhraseVisibility: ->
    @phrasesHidden(!@phrasesHidden())
    
  showTab: ->
    $("#page-#{@id}-link").tab('show')
    

class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @id = data['id']
    @name = data['name']
    @minSum = data['minSum']
    @maxSum = data['maxSum']
    @instructions = data['instructions']
    @phrases = []
    @phrasesById = {} # id => Phrase
    @selectedPhrase = ko.observable()  # Phrase object which is selected as the grade
    @annotations = ko.observableArray()
    @gradeRequired = false

    for phrase_data in data['phrases']
      phrase = new Phrase(@page, this)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)
      @phrasesById[phrase.id] = phrase
      @page.rubric.phrasesById[phrase.id] = phrase
    
    @grade = ko.computed((=>
      grades = []
      for annotation in @annotations()
        grades.push(annotation.grade()) if annotation.grade()?
      
      if grades.length > 0
        grade = @rubricEditor.calculateGrade(grades)
        grade = @minSum if @minSum? && grade < @minSum
        grade = @maxSum if @maxSum? && grade > @maxSum
        return grade
      
      if @selectedPhrase()
        return @selectedPhrase().grade
      
      return undefined
    ), this)

  setSelectedPhrase: (phrase) ->
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


class Phrase
  constructor: (@page, @criterion) ->
    @highlighted = ko.observable(false)
    @annotations = ko.observableArray()

  load_json: (data) ->
    @id = data['id']
    @categoryId = data['category']
    @grade = data['grade']
    @content = data['text']
    @escaped_content = @content.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
    
    @criterion.gradeRequired = true if @grade?


class @Rubric
  constructor: () ->
    @pages = []
    @pagesById = {}
    
    @feedbackCategories = []        # [{id: 0, name: 'Strenths'}, ...]
    @feedbackCategoriesById = {}    # id -> {}
    @finalComment = ''
    
    @grades = []
    @gradeIndexByValue = {}         # gradeValue -> index (0,1,2,..). Needed for calculating average from non-numeric values.
    @phrasesById = {}
    @numericGrading = false
    @gradingMode = 'none'
    
  #
  # Loads the rubric by AJAX
  #
  loadRubric: (url, callback) ->
    $.ajax
      type: 'GET'
      url: url
      #error: => @rubricEditor.onAjaxError()
      dataType: 'json'
      success: (data) =>
        this.parseRubric(data)
        callback() if callback
  
  #
  # Parses the JSON data returned by the server.
  #
  parseRubric: (data) ->
    data ||= {}
    
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

    previousPage = undefined
    for page_data in (data['pages'] || [])
      page = new Page(this, this)
      page.load_rubric(page_data)
      @pages.push(page)
      @pagesById[page.id] = page
      previousPage.nextPage = page if previousPage
      
      previousPage = page

    @finalComment = data['finalComment']

    if (@gradingMode == 'average' && @grades.length > 0) || @gradingMode == 'sum'
      @finishable = ko.computed((=>
        for page in @pages
          return false unless page.finished()
        
        return true
        ) , this)
    else
      @finishable = ko.observable(true)

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
  # If some grade is null or undefined, undefined is returned.
  # grades: array of grade values (strings or numbers)
  #
  calculateGradeMean: (grades) ->
    return undefined if !grades? || grades.length < 1
    
    nonNumericGradesSeen = false
    gradeSum = 0.0
    indexSum = 0
    indexCount = 0
    
    for grade in grades
      return undefined unless grade?
      
      numericGrade = parseFloat(grade)
      if isNaN(numericGrade)
        nonNumericGradesSeen = true
        index = @gradeIndexByValue[grade]
      else
        gradeSum += numericGrade
        index = @gradeIndexByValue[numericGrade]
    
      if index?
        indexSum += index
        indexCount += 1

    if @numericGrading
      if nonNumericGradesSeen
        return ''  # Grade must be selected manually
      else
        meanGrade = Math.round(gradeSum / grades.length)
        return meanGrade
    else
      return undefined if indexCount < 1
    
      meanIndex = Math.round(indexSum / indexCount)
      return @grades[meanIndex]
      
  
  #
  # Calculates sum of grades
  # grades: array of grade values (strings or numbers)
  calculateGradeSum: (grades) ->
    return undefined if !grades? || grades.length < 1
    
    gradeSum = 0.0
    
    for grade in grades
      return undefined unless grade?
      gradeSum += parseFloat(grade) if $.isNumeric(grade)
    
    return gradeSum



class @ReviewEditor extends @Rubric

  constructor: () ->
    super()
    
    @saved = true
    @finalGrade = ko.observable()
    @finishedText = ko.observable('')
    @finalizing = ko.observable(false)
    
    element = $('#review-editor')
    @demo_mode = element.data('demo')
    @initialPageId = element.data('initial-rubric-page')
    unless @demo_mode
      $(window).bind 'beforeunload', =>
        return "You have unsaved changes. Leave anyway?" unless @saved

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
  parseReview: (data) ->
    if data
      for page_data in data['pages']
        page = @pagesById[page_data['id']]
        continue unless page

        page.load_review(page_data)

        # Subscribe to grade changes
        page.grade.subscribe(=> @saved = false)
    
        for category in page.feedback
          category.value.subscribe((newValue) => @saved = false )
    
    if (@gradingMode == 'average' && @grades.length > 0)
      @averageGrade = ko.computed((=>
        grades = []
        for page in @pages
          grades.push(page.grade())
        
        return this.calculateGrade(grades)
      ), this)
    else if @gradingMode == 'sum'
      @averageGrade = ko.computed((=>
        grades = []
        for page in @pages
          grade = page.averageGrade()
          grades.push(grade) if grade?
        
        return this.calculateGrade(grades)
      ), this)
    else
      @averageGrade = ko.observable()

    ko.applyBindings(this)
    
    @finalGrade.subscribe(=> @saved = false )
    @finishedText.subscribe(=> @saved = false )
    
    # Activate the finalizing tab
    if @finalizing()
      $('#tab-finish-link').tab('show')
    else if @initialPageId
      initialPage = @pagesById[parseInt(@initialPageId)]
      initialPage.showTab() if initialPage

  # Returns the review as JSON
  encodeJSON: ->
    pages_json = @pages.map (page) -> page.to_json()
    return JSON.stringify({version: '2', pages: pages_json})
  
  # Populates the HTML-form from the model. This is called just before submitting.
  save: (options) ->
    options ||= {}
    
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
        
        $('#send_review').val('true') if options['send']?  # Send immediately?
    else
      status = 'started'
    
    $('#review_status').val(status)
    
    @saved = true
    
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

  saveAndSend: ->
    this.save({send: true})
    
  clickGrade: (phrase) =>
    phrase.page.addPhrase(phrase.content, phrase.categoryId) # unless phrase.criterion.selectedPhrase()?
    phrase.criterion.setSelectedPhrase(phrase) if phrase.grade?
    @saved = false
  
  clickPhrase: (phrase) =>
    this.clickGrade(phrase)
    
  clickCancelFinalize: (data, event) =>
    @finalizing(false)
    #event.preventDefault()
    #return false
    
  showNextPage: (page) =>
    if page.nextPage
      page.nextPage.showTab()
    else
      this.finish()
      $('#tab-finish-link').tab('show')
    
    window.scrollTo(0, 0)
    
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
    finalText = ''
    
    if @feedbackCategories.length > 1
      # Group feedback by category
      
      categoryTexts = {}  # category_id => 'feedback from a category'
      for page in @pages
        for page_category in page.feedback
          val = $.trim(page_category.value())
          
          categoryTexts[page_category.id] ||= ''
          categoryTexts[page_category.id] += val + '\n' if val.length > 0
      
      for category in @feedbackCategories
        categoryText = categoryTexts[category.id]
        continue if categoryText.length < 1
        
        finalText += "= #{category.name} =\n" if category.name.length > 0
        finalText += categoryText + '\n'
    
    else
      # Group feedback by page
      for page in @pages
        finalText += "= #{page.name} =\n" if page.name.length > 0
        
        for page_category in page.feedback
          val = $.trim(page_category.value())
          finalText += val + '\n' if val.length > 0
        
        finalText += '\n'
    
    # Final comment
    finalText += '\n' + @finalComment if @finalComment? && @finalComment.length > 0
    
    @finishedText(finalText)
  

  #
  # Callback for AJAX errors
  #
  onAjaxError: (jqXHR, textStatus, errorThrown) ->
    switch textStatus
      when 'timeout'
        alert('Server is not responding')
      else
        alert(errorThrown)
