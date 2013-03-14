#= require knockout-2.2.1
#= require bootstrap
#= require jquery.ui.sortable
#= require knockout-sortable-0.7.3

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


ko.bindingHandlers.editable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    $(element).click ->
      valueAccessor().editorActive(true)
  
  
  update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    options = valueAccessor()
    el = $(element)

    if ko.utils.unwrapObservable(options.editorActive)
      type = ko.utils.unwrapObservable(options.type) || 'textfield'
      original_value = ko.utils.unwrapObservable(options.value)
      
      #ko.utils.registerEventHandler element, "change", () ->
      #  observable = editorActive;
      #  observable($(element).datepicker("getDate"));
    
      # Create editor
      if 'textarea' == type
        input = $("<textarea>#{original_value}</textarea>")
      else
        input = $("<input type='textfield' value='#{original_value}' />")

      # Event handlers
      okHandler = (event) =>
        options.value(new String(input.val()))
        options.editorActive(false)
        event.stopPropagation()

      cancelHandler = (event) ->
        options.value(new String(original_value))
        options.editorActive(false)
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

      # Close on blur
      #input.blur(cancelHandler)

      # Stop propagation of clicks to prevent reopening the editor when clicking the input
      input.click (event) -> event.stopPropagation()

      # Replace original text with the editor
      el.empty()
      el.append(input)
      el.append('<br />') if 'textarea' == type
      el.append(ok)
      el.append(cancel)

      # Set focus to the editor
      input.focus()
      input.select()

      # handle disposal (if KO removes by the template binding)
      #ko.utils.domNodeDisposal.addDisposeCallback(element, () ->
        # TODO
        #$(element).editable("destroy")
      #)
    
    else
      placeholder = ko.utils.unwrapObservable(options.placeholder) || '-'
      value = ko.utils.unwrapObservable(options.value)
      
      # Show placeholder if value is empty
      value = placeholder if placeholder && (!value || value.length < 1)
      
      # Escape nasty characters
      value = value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')

      el.html(value)

}


class Page
  constructor: (@rubricEditor, data) ->
    @id = ko.observable()
    @name = ko.observable()
    @criteria = ko.observableArray()
    @grades = ko.observableArray()
    @editorActive = ko.observable(false)
    
    if data
      this.load_json(data)
    else
      this.initializeDefault()
      
    @tabUrl = ko.computed(() ->
        return "#page-#{@id()}"
      , this)
    @tabId = ko.computed(() ->
        return "page-#{@id()}"
      , this)
    @tabLinkId = ko.computed(() ->
        return "page-#{@id()}-link"
      , this)
    
    
    #@element = false  # The tab content div


  initializeDefault: () ->
    @id(@rubricEditor.nextPageId())
    @name('Untitled page')

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 1')
    @criteria.push(criterion)

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 2')
    @criteria.push(criterion)


  load_json: (data) ->
    @id(@rubricEditor.nextPageId(parseInt(data['id'])))
    @name(data['name'])

    # Load criteria
    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor, this, criterion_data)
      @criteria.push(criterion)

    # Load grades
    if data['grades']
      @grades.push(data['grades'])


  to_json: ->
    criteria = []
    grades = []

    for criterion in @criteria()
      criteria.push(criterion.to_json())

    for grade in @grades()
      grades.push(grade)

    return {id: @id(), name: @name(), criteria: criteria, grades: grades}




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


    # TODO: Criteria can be dropped into page tabs
#     @tab.droppable({
#       accept: '.criterion',
#       hoverClass: 'dropHover',
#       drop: (event) => @dropCriterionToSection(event)
#       tolerance: 'pointer'
#     })


  showTab: ->
    $('#' + @tabLinkId()).tab('show')


  activateTitleEditor: ->
    #new InPlaceEditor {element: @titleSpan}, (new_value) =>
    #  @name = new_value
    #  @tab.find('a').text(new_value)

  #
  # Deltes this page
  #
  deletePage: ->
    @rubricEditor.pages.remove(this)
    
    # Activate first tab
    $('#tab-settings-link').tab('show')

  #
  # Event handler: User clicks the 'Create criterion' button
  #
  clickCreateCriterion: (event) ->
    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

    criterion.activateEditor()

  clickCreateGrade: (event) ->
    @grades.push()
#     value = @gradeInput.val()
# 
#     this.addGrade(value)
# 
#     @gradeInput.val('')
#     @gradeInput.focus()
#     event.stopPropagation()

  addGrade: (value) ->
    # TODO
    return
    element = $(@rubricEditor.categoryTemplate({content: value}))
    td = element.find("td.category")
    td.data('value', value)

    activateEditor = -> new InPlaceEditor {element: td}

    element.find('.delete-button').click -> element.remove()
    element.find('.edit-button').click(activateEditor)
    td.click(activateEditor)

    @gradesTable.append(element)

  activateEditor: ->
    @editorActive(true)

#   dropCriterionToSection: (event) ->
#     console.log "Criterion was dropped into section tab"
#     console.log event


class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @name = ko.observable()
    @phrases = ko.observableArray()
    @editorActive = ko.observable(false)
    
    if data
      this.loadJson(data)
    else
      this.initializeDefault()
    
    
  initializeDefault: () ->
    @id = @rubricEditor.nextCriterionId()
    
    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What went well")
    @phrases.push(phrase)

    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What could be improved")
    @phrases.push(phrase)
    
    
  load_json: (data) ->
    @name(data['name'])
    @id = @rubricEditor.nextCriterionId(parseInt(data['id']))

    for phrase_data in data['phrases']
      phrase = new Phrase(@rubricEditor, this, phrase_data)
      @phrases.push(phrase)


  to_json: ->
    phrases = []

    for phrase in @phrases()
      phrases.push(phrase.to_json())

    return {id: @id, name: @name(), phrases: phrases}

  

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
    @editorActive(true)

  clickCreatePhrase: ->
    phrase = new Phrase(@rubricEditor, this)
    @phrases.push(phrase)

    phrase.activateEditor()


  deleteCriterion: ->
    @page.criteria.remove(this)


class Phrase
  constructor: (@rubricEditor, @criterion, data) ->
    @content = ko.observable()
    @editorActive = ko.observable(false)
    
    if data
      this.loadJson(data)
    else
      @id = @rubricEditor.nextPhraseId()


  load_json: (data) ->
    @id = @rubricEditor.nextPhraseId(parseInt(data['id']))
    @content(data['text'])


  to_json: ->
    return {id: @id, text: @content()} # TODO: type

  activateEditor: ->
    @editorActive(true)

  deletePhrase: ->
    @criterion.phrases.remove(this)


class CategoriesEditor
  constructor: (@rubricEditor) ->
    @element = $('#feedback-categories')
    @element.sortable({containment: 'parent', axis: 'y', distance: 5, helper: 'clone'}) # helper:clone is a workaround for a problem where click is fired after dropping and jQuery crashes. It may be fixed in future versions of jQuery.

    #$('#create-category-button').click =>
    #  this.addCategory('', {activateEditor: true})

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
    
    @gradingMode = ko.observable('average')
    @feedbackCategories = ko.observableArray()
    @finalComment = ko.observable('')
    @pages = ko.observableArray()

    #@categoriesEditor = new CategoriesEditor(this)

    @url = $('#rubric-editor').data('url')

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

  setHelpTexts: ->
    $('.help-hover').each (index, element) =>
      helpElementName = $(element).data('help')

      $(element).mouseenter ->
        $('#context-help > div').hide()
        $("##{helpElementName}").show()

  nextPageId: (id) ->
    if id
      @pageIdCounter = id if id > @pageIdCounter
      return @pageIdCounter
    else
      return @pageIdCounter++

  nextCriterionId: (id) ->
    if id 
      @criterionIdCounter = id if id > @criterionIdCounter
      return @criterionIdCounter
    else
      return @criterionIdCounter++

  nextPhraseId: (id) ->
    if id
      @phraseIdCounter = id if id > @phraseIdCounter
      return @phraseIdCounter
    else
      return @phraseIdCounter++

  initializeDefault: ->
    @gradingMode('average')
    @finalComment('')
    @feedbackCategories(['Strengths','Weaknesses','Other comments'])

    page = new Page(this)
    @pages.push(page)


  #
  # Creates a new rubric page
  #
  clickCreatePage: ->
    page = new Page(this)
    page.activateEditor()
    @pages.push(page)
    page.showTab()

  clickCreateCategory: ->
    @feedbackCategories.push('')
    # TODO: activate editor

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
    else
      @gradingMode(data['gradingMode'] || 'average')
      @finalComment(data['finalComment'] || '')
      
      if data['feedbackCategories']
        @feedbackCategories(data['feedbackCategories'])
      else
        @feedbackCategories(['Strengths','Weaknesses','Other comments'])

      for page_data in data['pages']
        page = new Page(this)
        page.load_json(page_data)
        @pages.push(page)
    
    ko.applyBindings(this)


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  clickSaveRubric: () ->
    # Generate JSON
    pages = []
    for page in @pages
      pages.push(page.to_json())

    json = {
      version: 1
      gradingMode: @gradingMode()
      finalComment: @finalComment()
      feedbackCategories: @feedbackCategories()
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
