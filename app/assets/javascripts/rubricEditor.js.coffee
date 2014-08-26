#= require knockout-2.2.1
#= require bootstrap
#= require jquery.ui.sortable
#= require knockout-sortable-0.7.3
#= require editable

# TODO
# preview (grader)
# preview (mail)
# page weights
# cut'n'paste



class Page
  constructor: (@rubricEditor) ->
    @id = ko.observable()
    @name = ko.observable('')
    @criteria = ko.observableArray()
    @editorActive = ko.observable(false)
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @criteria.subscribe => @rubricEditor.saved = false if @rubricEditor
    
    #if data
    #  this.load_json(data)
    #else
    #  this.initializeDefault()
      
    @tabUrl = ko.computed(() ->
        return "#page-#{@id()}"
      , this)
    @tabId = ko.computed(() ->
        return "page-#{@id()}"
      , this)
    @tabLinkId = ko.computed(() ->
        return "page-#{@id()}-link"
      , this)


  initializeDefault: () ->
    @id(@rubricEditor.nextId('page'))
    @name('Untitled page')

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 1')
    @criteria.push(criterion)

    criterion = new Criterion(@rubricEditor, this)
    criterion.name('Criterion 2')
    @criteria.push(criterion)


  load_json: (data) ->
    @id(@rubricEditor.nextId('page', parseInt(data['id'])))
    @name(data['name'])

    # Load criteria
    for criterion_data in data['criteria']
      @criteria.push(new Criterion(@rubricEditor, this, criterion_data))


  to_json: ->
    criteria = @criteria().map (criterion) -> criterion.to_json()

    return {id: @id(), name: @name(), criteria: criteria}

    # TODO: Criteria can be dropped into page tabs
#     @tab.droppable({
#       accept: '.criterion',
#       hoverClass: 'dropHover',
#       drop: (event) => @dropCriterionToSection(event)
#       tolerance: 'pointer'
#     })


  showTab: ->
    $('#' + @tabLinkId()).tab('show')


  #
  # Deltes this page
  #
  deletePage: ->
    @rubricEditor.pages.remove(this)
    
    $('#tab-settings-link').tab('show')  # Activate first tab
    
    @rubricEditor.saved = false if @rubricEditor

  #
  # Event handler: User clicks the 'Create criterion' button
  #
  clickCreateCriterion: (event) ->
    criterion = new Criterion(@rubricEditor, this)
    @criteria.push(criterion)

    criterion.activateEditor()

  activateEditor: ->
    @editorActive(true)


class Criterion
  constructor: (@rubricEditor, @page, data) ->
    @name = ko.observable('')
    @phrases = ko.observableArray()
    @editorActive = ko.observable(false)
    
    if data
      this.load_json(data)
    else
      this.initializeDefault()
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @phrases.subscribe => @rubricEditor.saved = false if @rubricEditor
    
  initializeDefault: () ->
    @id = @rubricEditor.nextId('criterion')
    
    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What went well")
    phrase.category(0)
    @phrases.push(phrase)

    phrase = new Phrase(@rubricEditor, this)
    phrase.content("What could be improved")
    phrase.category(1)
    @phrases.push(phrase)
    
    
  load_json: (data) ->
    @name(data['name'])
    @id = @rubricEditor.nextId('criterion', parseInt(data['id']))

    for phrase_data in data['phrases']
      @phrases.push(new Phrase(@rubricEditor, this, phrase_data))


  to_json: ->
    phrases = @phrases().map (phrase) -> phrase.to_json()

    return {id: @id, name: @name(), phrases: phrases}

  
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
    @content = ko.observable('')
    @category = ko.observable()
    @grade = ko.observable()         # Grade object
    @gradeValue = ko.observable()    # grade value (used in sum mode)
    @editorActive = ko.observable(false)
    
    if data
      this.load_json(data)
    else
      @id = @rubricEditor.nextId('phrase')
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
    @category.subscribe => @rubricEditor.saved = false if @rubricEditor
    @grade.subscribe => @rubricEditor.saved = false if @rubricEditor
    @gradeValue.subscribe => @rubricEditor.saved = false if @rubricEditor
    

  load_json: (data) ->
    @id = @rubricEditor.nextId('phrase', parseInt(data['id']))
    @content(data['text'])

    category = @rubricEditor.feedbackCategoriesById[data['category']]
    @category(category)
    
    grade = @rubricEditor.gradesByValue[data['grade']]
    @grade(grade)
    @gradeValue(data['grade'])


  to_json: ->
    json = { id: @id, text: @content() }
    json['category'] = @category().id if @category()
    
    # TODO: this could be less hacky
    if @rubricEditor.gradingMode() == 'sum'
      value = @gradeValue()
      if isNaN(value)
        gradeValue = value
      else
        gradeValue = parseFloat(value)
    else if @grade()
      gradeValue = @grade().to_json()
    else
      gradeValue = undefined
    
    json['grade'] = gradeValue
    
    return json

  activateEditor: ->
    @editorActive(true)

  deletePhrase: ->
    @criterion.phrases.remove(this)


class Grade
  constructor: (data, @container) ->
    @value = ko.observable(data || '')
    @editorActive = ko.observable(false)
  
  # Returns a number if the value can be interpreted as a number, otherwise returns the value as a string
  to_json: ->
    value = @value()
    
    if isNaN(value)
      return value
    else
      return parseFloat(value)
  
  activateEditor: ->
    @editorActive(true)
    
  deleteGrade: () ->
    return unless @container
    @container.remove(this)


class FeedbackCategory
  constructor: (@rubricEditor, data) ->
    @name = ko.observable('')
    @editorActive = ko.observable(false)
    
    @editorActive.subscribe => @rubricEditor.saved = false if @rubricEditor
  
    if data
      @name(data['name'])
      @id = @rubricEditor.nextId('feedbackCategory', data['id'])
    else
      @id = @rubricEditor.nextId('feedbackCategory')
  
  to_json: ->
    return {id: @id, name: @name()}
  
  deleteCategory: ->
    @rubricEditor.feedbackCategories.remove(this)
  
  activateEditor: ->
    @editorActive(true)


class RubricEditor

  constructor: () ->
    @saved = true
    @idCounters = {page: 0, criterion: 0, phrase: 0, feedbackCategory: 0}
    
    @gradingMode = ko.observable('average')    # String
    @grades = ko.observableArray()             # Array of Grade objects
    @gradesByValue = {}                        # string => Grade
    @feedbackCategories = ko.observableArray() # Array of FeedbackCategory objects
    @feedbackCategoriesById = {}               # id => FeedbackCategory
    @finalComment = ko.observable('')
    @pages = ko.observableArray()

    @url = $('#rubric-editor').data('url')
    @demo_mode = $('#rubric-editor').data('demo')

    unless @demo_mode
      $(window).bind 'beforeunload', => return "You have unsaved changes. Leave anyway?" unless @saved

    this.setHelpTexts()

    #this.loadRubric(@url)
    this.parseRubric(window.rubric)

  
  subscribeToChanges: ->
    notSaved = => @saved = false
    
    @grades.subscribe -> notSaved()
    @feedbackCategories.subscribe -> notSaved()
    @gradingMode.subscribe -> notSaved()
    

  setHelpTexts: ->
    $('.help-hover').each (index, element) =>
      helpElementName = $(element).data('help')

      $(element).mouseenter ->
        $('#context-help > div').hide()
        $("##{helpElementName}").show()

  # nextId('counter') returns the next available id number for 'counter'
  # nextId('counter', newId) increases the counter to newId and returns newId. If next available id is higher than newId, the counter is not increased.
  nextId: (counterName, idNumber) ->
    if idNumber?
      @idCounters[counterName] = idNumber if idNumber > @idCounters[counterName]
      return idNumber
    else
      return ++@idCounters[counterName]


  initializeDefault: ->
    @gradingMode('average')
    @finalComment('')
    #@feedbackCategories([new FeedbackCategory(this, {name: 'Strengths', id:0}),new FeedbackCategory(this, {name:'Weaknesses', id:1}),new FeedbackCategory(this, {name:'Other comments', id:2})])

    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)


  #
  # Creates a new rubric page
  #
  clickCreatePage: ->
    page = new Page(this)
    page.initializeDefault()
    @pages.push(page)
    page.showTab()
    page.activateEditor()


  clickCreateCategory: ->
    originalCategoryCount = @feedbackCategories().length
    
    # Don't allow more than 3 categories
    return if originalCategoryCount >= 3
  
    new_category_count = if originalCategoryCount == 0 then 2 else 1
    for i in [0...new_category_count]
      new_category = new FeedbackCategory(this, {name: '', id: this.nextId('feedbackCategory')})
      @feedbackCategories.push(new_category)
      new_category.activateEditor()

  createGrade: () ->
    grade = new Grade('', @grades)
    @grades.push(grade)
    grade.activateEditor()

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
      
      # Load feedback categories
      if data['feedbackCategories']
        for raw_category in data['feedbackCategories']
          category = new FeedbackCategory(this, raw_category)
          @feedbackCategories.push(category)
          @feedbackCategoriesById[category.id] = category

      # Load grades
      if data['grades']
        for grade in data['grades']
          if grade?
            grade = new Grade(grade.toString(), @grades)
            @grades.push(grade)
            @gradesByValue[grade.value()] = grade

      # Load pages
      for page_data in data['pages']
        page = new Page(this)
        page.load_json(page_data)
        @pages.push(page)
    
    ko.applyBindings(this)
    this.subscribeToChanges()
    @saved = true


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  clickSaveRubric: () ->
    # Generate JSON
    pages = @pages().map (page) -> page.to_json()
    categories = @feedbackCategories().map (category) -> category.to_json()
    grades = @grades().map (grade) -> grade.to_json()

    json = {
      version: '2'
      pages: pages
      feedbackCategories: categories
      grades: grades
      gradingMode: @gradingMode()
      finalComment: @finalComment()
    }
    json_string = JSON.stringify(json)

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
  new RubricEditor()

  $('.tooltip-help').popover({placement: 'right', trigger: 'hover', html: true})
  #$('#tooltip-final-comment').popover({placement: 'right', trigger: 'hover', html: true})
