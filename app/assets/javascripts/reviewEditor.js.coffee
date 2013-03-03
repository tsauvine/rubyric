#= require handlebars-1.0.0.beta.6
#= require bootstrap

class Page
  constructor: (@rubricEditor) ->
    @criteria = []
    @element = false  # The tab content div

  load_json: (data) ->
    @name = data['name']
    @id = parseInt(data['id'])

    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this)
      criterion.load_json(criterion_data)
      @criteria.push(criterion)

  to_json: ->
    # TODO: grade

    json = {
      id: @id,
      good: @goodTextarea.val(),
      bad: @badTextarea.val(),
      neutral: @neutralTextarea.val()
    }

    return json

  createDom: () ->
    @element = $(@rubricEditor.pageTemplate({id: @id, name: @name}))
    @element.data('page', this)

    @rubricDiv = @element.find('.rubric')
    @rubricDiv.data('page', this)

    @goodTextarea = @element.find('textarea.good')
    @badTextarea = @element.find('textarea.bad')
    @neutralTextarea = @element.find('textarea.neutral')

    # Attach event handlers

    # Add criteria
    for criterion in @criteria
      @rubricDiv.append(criterion.createDom())

    return @element


  addToDom: ->
    # Add tab
    @tab = $("<li><a href='#page-#{@id}' data-toggle='tab'>#{@name}</a></li>")
    $('#tabs').append(@tab)

    # Add content
    $('#tab-contents').append(this.createDom())

  showTab: ->
    @tab.find('a').tab('show')


class Criterion
  constructor: (@rubricEditor, @page) ->
    @phrases = []
    #@editorActive = false

  load_json: (data) ->
    @name = data['name']
    @id = parseInt(data['id'])

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, @page)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)

  createDom: () ->
    @element = $(@rubricEditor.criterionTemplate({criterionId: @id, criterionName: @name}))
    @element.data('criterion', this)
    @phrasesElement = @element.find('tbody')

    # Add phrases
    for phrase in @phrases
      @phrasesElement.append(phrase.createDom())

    return @element


class Phrase
  constructor: (@rubricEditor, @page) ->

  load_json: (data) ->
    @content = data['text']
    @category = parseInt(data['category'])
    @id = parseInt(data['id'])

  createDom: () ->
    escaped_content = @content.replace('\n','<br />')
    @element = $(@rubricEditor.phraseTemplate({id: @id, content: escaped_content}))
    @element.data('phrase', this)

    @phraseTd = @element.find("td.phrase")
    @phraseTd.data('value', @content)
    @phraseTd.click (event) => @clickPhrase()

    @element.find('.delete-phrase-button').click => @deletePhrase()
    @element.find('.edit-phrase-button').click => @activateEditor()

    return @element

  clickPhrase: ->
    switch @category
      when 2 then textarea = @page.neutralTextarea
      when 1 then textarea = @page.badTextarea
      else textarea = @page.goodTextarea

    textarea.val(textarea.val() + @content + '\n')


class ReviewEditor

  constructor: () ->
    @pages = []

    # Load Handlebar templates
    @pageTemplate = Handlebars.compile($("#page-template").html());
    @criterionTemplate = Handlebars.compile($("#criterion-template").html());
    @phraseTemplate = Handlebars.compile($("#phrase-template").html());

    @rubric_url = $('#review-editor').data('rubric-url')
    @review_url = $('#review-editor').data('review-url')

    this.loadRubric(@rubric_url)


  clickFinish: ->
    this.save()

    # TODO: redirect


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
  # Parses the JSON data returned by the server. See loadRubric.
  #
  parseRubric: (data) ->
    unless data
      alert('Rubric has not been prepared')
      return

    for page_data in data['pages']
      page = new Page(this)
      page.load_json(page_data)
      page.addToDom()
      @pages.push(page)

    # Add finish button
    tab = $("<button class='btn btn-success'>Finish</button>")
    tab.click => @clickFinish()
    $('#tabs').append(tab)

  save: ->
    pages_json = []

    for page in @pages
      pages_json.push(page.to_json())

    json = {pages: pages_json}
    json_string = JSON.stringify(json)

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
