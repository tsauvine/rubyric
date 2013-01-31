#= require handlebars-1.0.0.beta.6
#= require bootstrap
#= require jquery.ui.sortable

#// require bootstrap-dropdown
#// require bootstrap-popover
#// require jquery.jeditable
#// require jquery-ui-1.8.19.custom.min

# TODO:
# grades
# grading mode
# final comment
#
# TODO
# preview (grader)
# preview (mail)
# captions: strengths, weaknesses, other comments
# page weights
# quality levels
# cut'n'paste
# feedback grouping


class InPlaceEditor
  # After editing, the new un-escaped value will be placed in data('value')
  # options:
  #   element: Element that will contain the editor. After editing, the element will contain the new value.
  #   value: initial value. Default: data('value')
  #   emptyPlaceholder: content to be shown if entered value is empty
  #   type: 'textfield' (default), 'textarea'
  constructor: (@options, callback) ->
    element = options['element']
    type = options['type'] || 'textfield'
    emptyPlaceholder = options['emptyPlaceholder'] || ''

    original_value = element.data('value')
    initial_value = options['value'] || original_value || ''

    # Create editor
    if 'textarea' == type
      input = $("<textarea>#{initial_value}</textarea>")
    else
      input = $("<input type='textfield' value='#{initial_value}' />")

    displayValue = (value) ->
      value = emptyPlaceholder if !value || value.length < 1
      element.html(value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />'))

    # Event handlers
    okHandler = (event) =>
      new_value = input.val()
      displayValue(new_value)
      element.data('value', new_value) # Replace the editor with the new text. Store the unescaped value in data.
      callback(new_value) if callback
      event.stopPropagation()

    cancelHandler = (event) ->
      #original_value_escaped = original_value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
      #element.html(original_value_escaped)  # Replace the editor with the original text.
      displayValue(original_value)
      event.stopPropagation()

    # Make buttons
    ok = $('<button>OK</button>').click(okHandler)
    cancel = $('<button>Cancel</button>').click(cancelHandler)

    # Attach event handlers
    input.keyup (event) ->
      switch event.keyCode
        when 13
          okHandler(event) unless type == 'textarea'
        when 27 then cancelHandler(event)

      # Prevent esc from closing the dialog
      event.stopPropagation()

    #input.blur(cancelHandler)

    # Stop propagation of clicks to prevent reopening the editor
    input.click (event) -> event.stopPropagation()

    # Replace original text with the editor
    element.empty()
    element.append(input)
    element.append('<br />') if 'textarea' == type
    element.append(ok)
    element.append(cancel)

    # Set focus to the editor
    input.focus()
    input.select()

    return element



class Page
  constructor: (@rubricEditor, @id) ->
    @id ||= @rubricEditor.nextPageId()

    @criteria = []
    @grades = []
    @element = false  # The tab content div

  load_json: (data) ->
    @name = data['name']

    @id = @rubricEditor.nextPageId(parseInt(data['id']))

    # Load criteria
    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor)
      criterion.load_json(criterion_data)
      @criteria.push(criterion)

    # Load grades
    if data['grades']
      @grades = data['grades']


  to_json: ->
    criteria = []
    grades = []

    @rubricDiv.find('div.criterion').each (index, element) =>
      criterion = $(element).data('criterion')
      criteria.push(criterion.to_json()) if criterion

    @gradesTable.find('td.category').each (index, element) =>
      grades.push($(element).data('value'))

    return {id: @id, name: @name, criteria: criteria, grades: grades}

  initializeDefault: () ->
    @name = 'Untitled page'

    criterion = new Criterion(@rubricEditor)
    criterion.initializeDefault()
    criterion.name = 'Criterion 1'
    @criteria.push(criterion)

    criterion = new Criterion(@rubricEditor)
    criterion.initializeDefault()
    criterion.name = 'Criterion 2'
    @criteria.push(criterion)


  createDom: () ->
    @element = $(@rubricEditor.pageTemplate({id: @id, name: @name}))
    @element.data('page', this)
    @rubricDiv = @element.find('.rubric')
    @titleSpan = @element.find('span.title')
    @gradeInput = @element.find('input')
    @gradesTable = @element.find('tbody.grading')

    @rubricDiv.data('page', this)
    @titleSpan.data('value', @name)

    # Criteria and grades are sortable
    @rubricDiv.sortable {containment: '#rubric-editor', distance: 5}
    @gradesTable.sortable {containment: 'parent', axis: 'y', distance: 5} # , helper: 'clone'

    # Attach event handlers
    @element.find('.create-criterion-button').click (event) => @clickCreateCriterion(event)
    @element.find('.delete-page-button').click => @deletePage()
    @element.find('.edit-page-button').click => @activateTitleEditor()
    @element.find('.create-grade-button').click (event) => @clickCreateGrade(event)
    @gradeInput.keyup (event) =>
      switch event.keyCode
        when 13  # enter
          @clickCreateGrade(event)
        when 27  # esc
          @gradeInput.val('')
      event.stopPropagation()

    @titleSpan.click => @activateTitleEditor()

    # Add criteria
    for criterion in @criteria
      @rubricDiv.append(criterion.createDom())

    # Add grades
    for grade in @grades
      this.addGrade(grade)

    return @element


  addToDom: ->
    # Add tab
    @tab = $("<li><a href='#page-#{@id}' data-toggle='tab'>#{@name}</a></li>")
    $('#create-page-tab').before(@tab)

    # TODO: Criteria can be dropped into page tabs
#     @tab.droppable({
#       accept: '.criterion',
#       hoverClass: 'dropHover',
#       drop: (event) => @dropCriterionToSection(event)
#       tolerance: 'pointer'
#     })

    # Add content
    $('#tab-contents').append(this.createDom())

  showTab: ->
    @tab.find('a').tab('show')


  activateTitleEditor: ->
    new InPlaceEditor {element: @titleSpan}, (new_value) =>
      @name = new_value
      @tab.find('a').text(new_value)

  #
  # Deltes this page
  #
  deletePage: ->
    # Activate first tab
    $('#tab-settings-link').tab('show')

    # Remove from DOM
    @tab.remove()
    @element.remove()

  #
  # Event handler: User clicks the 'Create criterion' button
  #
  clickCreateCriterion: (event) ->
    # Create criterion object
    criterion = new Criterion(@rubricEditor)

    # Add to criterion model
    this.criteria.push(criterion)

    # Add to DOM
    @rubricDiv.append(criterion.createDom())

    criterion.activateEditor()

  clickCreateGrade: (event) ->
    value = @gradeInput.val()

    this.addGrade(value)

    @gradeInput.val('')
    @gradeInput.focus()
    event.stopPropagation()

  addGrade: (value) ->
    element = $(@rubricEditor.categoryTemplate({content: value}))
    td = element.find("td.category")
    td.data('value', value)

    activateEditor = -> new InPlaceEditor {element: td}

    element.find('.delete-button').click -> element.remove()
    element.find('.edit-button').click(activateEditor)
    td.click(activateEditor)

    @gradesTable.append(element)


#   dropCriterionToSection: (event) ->
#     console.log "Criterion was dropped into section tab"
#     console.log event


class Criterion
  constructor: (@rubricEditor, @id) ->
    @id ||= @rubricEditor.nextCriterionId()

    @name = 'Criterion'
    @phrases = []
    #@editorActive = false

  load_json: (data) ->
    @name = data['name']
    @id = @rubricEditor.nextCriterionId(parseInt(data['id']))

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor)
      phrase.load_json(phrase_data)
      @phrases.push(phrase)

  to_json: ->
    phrases = []

    @phrasesElement.find('tr.phrase').each (index, element) =>
      phrase = $(element).data('phrase')
      phrases.push(phrase.to_json()) if phrase

    return {id: @id, name: @name, phrases: phrases}

  initializeDefault: () ->
    phrase = new Phrase(@rubricEditor)
    phrase.content = "What went well"
    @phrases.push(phrase)

    phrase = new Phrase(@rubricEditor)
    phrase.content = "What could be improved"
    @phrases.push(phrase)

  createDom: () ->
    @element = $(@rubricEditor.criterionTemplate({criterionId: @id, criterionName: @name}))
    @element.data('criterion', this)
    @phrasesElement = @element.find('tbody')

    @nameElement = @element.find('span.title')
    @nameElement.click => @activateEditor()
    @nameElement.data('value', @name)

    @element.find('.create-phrase-button').click (event) => @clickCreatePhrase(event)
    @element.find('.delete-criterion-button').click => @deleteCriterion()
    @element.find('.edit-criterion-button').click => @activateEditor()

    # Quality levels are sortable
    #$(".grading-options ul").sortable()
    #$(".grading-options").sortable({containment: 'parent'})

    #$(document).on('click', '.create-phrase-button', $.proxy(@phraseCreate, this))

    # Phrases are sortable
    @phrasesElement.sortable({
      containment: '#rubric-editor',
      axis: 'y',
      distance: 5,
      connectWith: "table.phrases tbody"
    })

    # Add phrases
    for phrase in @phrases
      @phrasesElement.append(phrase.createDom())

    return @element

  activateEditor: ->
    new InPlaceEditor {element: @nameElement}, (new_value) =>
      @name = new_value

  clickCreatePhrase: ->
    # Create criterion object
    phrase = new Phrase(@rubricEditor)

    # Add to criterion model
    this.phrases.push(phrase)

    # Add to DOM
    @phrasesElement.append(phrase.createDom())

    phrase.activateEditor()

  deleteCriterion: ->
    @element.remove()


class Phrase
  constructor: (@rubricEditor, @id) ->
    @id ||= @rubricEditor.nextPhraseId()
    @content = ''
    #@editorActive = false

  load_json: (data) ->
    @content = data['text']
    @id = @rubricEditor.nextPhraseId(parseInt(data['id']))

  to_json: ->
    return {id: @id, text: @content} # TODO: type

  createDom: () ->
    escaped_content = @content.replace('\n','<br />')
    @element = $(@rubricEditor.phraseTemplate({id: @id, content: escaped_content}))
    @element.data('phrase', this)

    @phraseTd = @element.find("td.phrase")
    @phraseTd.data('value', @content)
    @phraseTd.click (event) => @activateEditor()

    @element.find('.delete-phrase-button').click => @deletePhrase()
    @element.find('.edit-phrase-button').click => @activateEditor()

    return @element

  activateEditor: ->
    new InPlaceEditor {element: @phraseTd, type: 'textarea'}, (new_value) =>
      @content = new_value

  deletePhrase: ->
    @element.remove()


class CategoriesEditor
  constructor: (@rubricEditor) ->
    @element = $('#feedback-categories')
    @element.sortable({containment: 'parent', axis: 'y', distance: 5, helper: 'clone'}) # helper:clone is a workaround for a problem where click is fired after dropping and jQuery crashes. It may be fixed in future versions of jQuery.

    $('#create-category-button').click =>
      this.addCategory('', {activateEditor: true})

  setCategories: (new_categories) ->
    $('#feedback-categories').empty()

    # Make sure there is at least one category
    new_categories.push('') if new_categories.length < 1

    for category in new_categories
      this.addCategory(category)

  addCategory: (content, options) ->
    options ||= {}

    if !content || content.length < 1
      visible_content = '<no title>'
    else
      visible_content = content

    element = $(@rubricEditor.categoryTemplate({content: visible_content}))
    td = element.find("td.category")
    td.data('value', content)

    activateEditor = -> new InPlaceEditor {element: td, emptyPlaceholder: '<no title>'}
    td.click(activateEditor)
    element.find('.edit-button').click(activateEditor)
    element.find('.delete-button').click ->
      element.remove()

    @element.append(element)

    activateEditor() if options['activateEditor']

    return element

  getCategories: ->
    categories = []
    $('#feedback-categories td.category').each (index, element) ->
      categories.push($(element).data('value'))

    return categories


class RubricEditor

  constructor: () ->
    @saved = true
    @pageIdCounter = 0
    @criterionIdCounter = 0
    @phraseIdCounter = 0

    # Load Handlebar templates
    @pageTemplate = Handlebars.compile($("#page-template").html())
    @criterionTemplate = Handlebars.compile($("#criterion-template").html())
    @phraseTemplate = Handlebars.compile($("#phrase-template").html())
    @categoryTemplate = Handlebars.compile($("#category-template").html())

    @categoriesEditor = new CategoriesEditor(this)

    @url = $('#rubric-editor').data('url')

    $('#create-page').click => @pageCreate()
    $('#save-button').click => @saveRubric()

    $(window).bind 'beforeunload', => return "You have unsaved changes. Leave anyway?" unless @saved

    this.setHelpTexts()

    this.loadRubric(@url)
#     @phraseEditableParams = {
#       type: 'textarea',
#       rows: 3,
#       onblur: 'ignore',
#       submit: 'Save',
#       cancel: 'Cancel'
#     }

    #@pages = []

    # Indexes
    #@pagesById = {}
    #@criteriaById = {}
    #@phrasesById = {}

  setHelpTexts: ->
    $('.help-hover').each (index, element) =>
      helpElementName = $(element).data('help')

      $(element).mouseenter ->
        $('#context-help > div').hide()
        $("##{helpElementName}").show()

  nextPageId: (id) ->
    if id && id > @pageIdCounter
      return @pageIdCounter = id
    else
      return @pageIdCounter++

  nextCriterionId: (id) ->
    if id && id > @criterionIdCounter
      return @criterionIdCounter = id
    else
      return @criterionIdCounter++

  nextPhraseId: (id) ->
    if id && id > @phraseIdCounter
      return @phraseIdCounter = id
    else
      return @phraseIdCounter++

  initializeDefault: ->
    @gradingMode = 'average'
    @finalComment = ''
    @categoriesEditor.setCategories(['Strengths','Weaknesses','Other comments'])
    this.updateGeneralSettings()

    page = new Page(this)
    page.initializeDefault()
    page.addToDom()

  updateGeneralSettings: () ->
    $("#grading-mode-#{@gradingMode}").attr('checked', true)
    $('#final-comment').val(@finalComment)

  #
  # Creates a new rubric page
  #
  pageCreate: ->
    page = new Page(this)
    page.initializeDefault()
    page.addToDom()
    page.showTab()
    page.activateTitleEditor()
    #@pages.push(page)
    #@pagesById[pageId] = page

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
    if !data
      this.initializeDefault()
      return

    @gradingMode = data['gradingMode'] || 'average'
    @finalComment = data['finalComment'] || ''
    this.updateGeneralSettings()
    @categoriesEditor.setCategories(data['feedbackCategories'] || ['Strengths','Weaknesses','Other comments'])

    for page_data in data['pages']
      page = new Page(this)
      page.load_json(page_data)
      page.addToDom()


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  saveRubric: () ->
    # Read general settings
    gradingMode = $('input:checked', '#grading-mode').val()
    finalComment = $('#final-comment').val()
    feedbackCategories = @categoriesEditor.getCategories()

    # Read page contents
    pages = []
    $('#tab-contents .tab-pane').each (index, element) ->
      return if index == 0  # Skip settings page

      page = $(element).data('page')
      pages.push(page.to_json()) if page

    # Generate JSON
    json = {
      version: 1
      gradingMode: gradingMode
      finalComment: finalComment
      feedbackCategories: feedbackCategories
      pages: pages
    }
    json_string = JSON.stringify(json)
    #console.log json_string

    # AJAX call
    $.ajax
      type: 'PUT',
      url: @url,
      data: {rubric: json_string},
      error: $.proxy(@onAjaxError, this)
      dataType: 'json'
      success: (data) =>
        @saved = true
        alert('Changes saved')


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
  new RubricEditor
