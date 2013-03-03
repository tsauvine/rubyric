#= require knockout-2.2.1
#= require bootstrap

class Page
  constructor: (@rubricEditor) ->
    @criteria = []
    
    @goodFeedback = ko.observable('')
    @badFeedback = ko.observable('')
    @neutralFeedback = ko.observable('')

  load_json: (data) ->
    @name = data['name']
    @id = parseInt(data['id'])
    @dom_id = 'page-' + @id
    @link = '#page-' + @id

    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this)
      criterion.load_json(criterion_data)
      @criteria.push(criterion)

  load_review: (data) ->
    @goodFeedback(data['good'])
    @badFeedback(data['bad'])
    @neutralFeedback(data['neutral'])

  to_json: ->
    # TODO: grade

    json = {
      id: @id,
      good: @goodFeedback(),
      bad: @badFeedback(),
      neutral: @neutralFeedback()
    }

    return json

  addPhrase: (content, category) ->
    switch category
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
    #@editorActive = false

  load_json: (data) ->
    @name = data['name']
    @id = parseInt(data['id'])
    @dom_id = 'criterion-' + @id

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, @page)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)



class Phrase
  constructor: (@rubricEditor, @page) ->

  load_json: (data) ->
    @content = data['text']
    @escaped_content = @content.replace('\n','<br />')
    
    @category = parseInt(data['category'])
    @id = parseInt(data['id'])
    @dom_id = 'phrase-' + @id

  clickPhrase: ->
    @page.addPhrase(@content, @category)


class ReviewEditor

  constructor: () ->
    @pages = []
    @pagesById = {}

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

    @feedbackCategories = data['feedbackCategories']

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
        #window.location.href = "#{@review_url}/finish" # TODO

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
