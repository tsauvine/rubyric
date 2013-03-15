#= require knockout-2.2.1
#= require bootstrap

class Page
  constructor: (@rubricEditor) ->
    @criteria = []
    @grade = ko.observable()
    
    @goodFeedback = ko.observable('')
    @badFeedback = ko.observable('')
    @neutralFeedback = ko.observable('')

  load_json: (data) ->
    @name = data['name']
    @id = data['id']
    @dom_id = 'page-' + @id
    @link = '#page-' + @id

    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this)
      criterion.load_json(criterion_data)
      @criteria.push(criterion)
  
  load_review: (data) ->
    if data['feedback'] && data['feedback'].length > 2
      @goodFeedback(data['feedback'][0])
      @badFeedback(data['feedback'][1])
      @neutralFeedback(data['feedback'][2])
    
    if data['grade']
      @grade(data['grade'])

  to_json: ->
    json = {
      id: @id,
      feedback: [@goodFeedback(), @badFeedback(), @neutralFeedback()],
      grade: @grade()
    }

    return json

  addPhrase: (content, category) ->
    categoryIndex = @rubricEditor.feedbackCategoriesIndex[category]
    
    switch categoryIndex
      when 2
        @neutralFeedback(@neutralFeedback() + content + "\n")
      when 1
        @badFeedback(@badFeedback() + content + "\n")
      else
        @goodFeedback(@goodFeedback() + content + "\n")
  
  
#   showTab: ->
#     @tab.find('a').tab('show')


class Criterion
  constructor: (@rubricEditor, @page) ->
    @phrases = []

  load_json: (data) ->
    @id = data['id']
    @name = data['name']
    @dom_id = 'criterion-' + @id

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, @page)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)



class Phrase
  constructor: (@rubricEditor, @page) ->

  load_json: (data) ->
    @id = data['id']
    @category = data['category']
    @content = data['text']
    @escaped_content = @content.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
    
    @dom_id = 'phrase-' + @id

  clickPhrase: ->
    @page.addPhrase(@content, @category)


class ReviewEditor

  constructor: () ->
    @pages = []
    @pagesById = {}
    
    @feedbackCategories = []
    @feedbackCategoriesIndex = {}
    @grades = []
    @gradingMode = 'none'
    @finalComment = ''

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
  # Loads the review by AJAX
  #
  loadReview: (url) ->
    $.ajax
      type: 'GET'
      url: url
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        this.parseReview(data)


  #
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseRubric: (data) ->
    unless data
      alert('Rubric has not been prepared')
      return

    if data['feedbackCategories']
      category_counter = 0
      for category in data['feedbackCategories']
        @feedbackCategories.push(category)
        @feedbackCategoriesIndex[category] = category_counter++

    if data['grades']
      @grades.push(null)
      for grade in data['grades']
        @grades.push(grade)

    for page_data in data['pages']
      page = new Page(this)
      page.load_json(page_data)
      @pages.push(page)
      @pagesById[page.id] = page

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
    pages_json = []

    for page in @pages
      pages_json.push(page.to_json())

    json_string = JSON.stringify({pages: pages_json})

    # AJAX call
    $.ajax
      type: 'PUT',
      url: @review_url,
      data: {review: json_string},
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        window.location.href = "#{@review_url}/finish"

    #console.log "#{@review_url}/finish"

  clickFinish: ->
    this.save()

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
