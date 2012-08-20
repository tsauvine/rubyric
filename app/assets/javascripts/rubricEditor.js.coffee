#= require handlebars-1.0.0.beta.6
#= require jquery.jeditable
#= require jquery-ui-1.8.19.custom.min
#= require bootstrap-tab
#= require bootstrap-modal

#// require bootstrap-dropdown
#// require bootstrap-popover

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
  #   type: 'textfield' (default), 'textarea'
  constructor: (@options, callback) ->
    element = options['element']
    type = options['type'] || 'textfield'

    original_value = element.data('value')
    initial_value = options['value'] || original_value  || ''

    # Create editor
    if 'textarea' == type
      input = $("<textarea>#{initial_value}</textarea>")
    else
      input = $("<input type='textfield' value='#{initial_value}' />")

    # Event handlers
    okHandler = (event) =>
      new_value = input.val()
      new_value_escaped = new_value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
      #console.log new_value_escaped
      element.html(new_value_escaped).data('value', new_value) # Replace the editor with the new text. Store the unescaped value in data.
      callback(new_value) if callback
      event.stopPropagation()

    cancelHandler = (event) ->
      original_value_escaped = original_value.replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')
      element.html(original_value_escaped)  # Replace the editor with the original text.
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
    @element = false  # The tab content div

  load_json: (data) ->
    @name = data['name']
    console.log "Create page #{@name}"
    @id = @rubricEditor.nextPageId(parseInt(data['id']))

    for criterion_data in data['criteria']
      criterion = new Criterion(@rubricEditor)
      criterion.load_json(criterion_data)
      @criteria.push(criterion)

  to_json: ->
    criteria = []

    @rubricDiv.find('div.criterion').each (index, element) =>
      criterion = $(element).data('criterion')
      criteria.push(criterion.to_json()) if criterion

    return {id: @id, name: @name, criteria: criteria}

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

    @rubricDiv.data('page', this)
    @titleSpan.data('value', @name)

    # Criteria are sortable
    @rubricDiv.sortable(
      {containment: '#rubric-editor', distance: 5}
    )

    # Attach event handlers
    @element.find('.create-criterion-button').click (event) => @clickCreateCriterion(event)
    @element.find('.delete-page-button').click => @deletePage()
    @element.find('.edit-page-button').click => @activateTitleEditor()
    @titleSpan.click => @activateTitleEditor()

    # Add criteria
    for criterion in @criteria
      @rubricDiv.append(criterion.createDom())

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

    # Add to index
    #@criteriaById[criterionId] = criterion

    # Add to criterion model
    this.criteria.push(criterion)

    # Add to DOM
    @rubricDiv.append(criterion.createDom())

    criterion.activateEditor()

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
    console.log "Create criterion #{@name}"
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
    console.log "Create phrase #{@content}"
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


class RubricEditor

  constructor: () ->
    @pageIdCounter = 0
    @criterionIdCounter = 0
    @phraseIdCounter = 0

    # Load Handlebar templates
    @pageTemplate = Handlebars.compile($("#page-template").html());
    @criterionTemplate = Handlebars.compile($("#criterion-template").html());
    @phraseTemplate = Handlebars.compile($("#phrase-template").html());

    @url = $('#rubric-editor').data('url')
    console.log "URL: #{@url}"

    $('#create-page').click => @pageCreate()
    $('#save-button').click => @saveRubric()

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
    page = new Page(this)
    page.initializeDefault()
    page.addToDom()

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
    if data
      for page_data in data['pages']
        page = new Page(this)
        page.load_json(page_data)
        page.addToDom()
    else
      this.initializeDefault()


  #
  # Sends the JSON encoded rubric to the server by AJAX
  #
  saveRubric: () ->
    #console.log JSON.stringify(@questionsByQuestionId, ['id','type'])

    #for question_id, question of @questionsByQuestionId
    #  console.log JSON.stringify(question, ['question_id','type'])

    pages = []

    $('#tab-contents .tab-pane').each (index, element) =>
      return if index == 0  # Skip settings page

      page = $(element).data('page')
      pages.push(page.to_json()) if page

    json = {pages: pages}
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


  #
  # Collects and concatenates the text nodes under an element (non-recursively).
  # Other elements are replaced with '\n'. Returns a string.
  #
#   collectText(element) ->
#     text = $A(element.childNodes).collect( (node) {
#       return (node.nodeType == 3 ? node.nodeValue.strip() : '\n')
#     }).join('')
#     return text

  #
  # Copies item grading options to the clipboard.
  #
#  copyItemGrades(item_id) ->
#     texts_clipboard = []
#     points_clipboard = []
#
#     # Push the text to the clipboard
#     elements = $$("#item-grades" + item_id + " .itemGradingOption")
#     for (i = 0; i < elements.length; i++) {
#       if (elements[i].firstChild) {
#         texts_clipboard.push(elements[i].firstChild.data)
#         points_clipboard.push('0')
#       }
#     }
#
#     # Flash the table
#     source_element = $("item-grades" + item_id)
#     new Effect.Highlight(source_element, {startcolor: "#f0f0f0", endcolor: "#ffffff", duration: .5, queue:{position: 'end', scope: 'copyscope', limit: 1}})


  #
  # Copies section grading options to the clipboard.
  #
#   copySectionGrades(section_id) ->
#     # Push the text to the clipboard
#     texts = $$("#section-grades" + section_id + " .sectionGradingText")
#     points = $$("#section-grades" + section_id + " .sectionGradingPoints")
#     texts_clipboard = []
#     points_clipboard = []
#
#     for (i = 0; i < texts.length; i++) {
#       texts_clipboard.push(texts[i].firstChild.data)
#       points_clipboard.push(points[i].firstChild.data)
#     }
#
#     # Flash the table
#     source_element = $("section-grades" + section_id)
#     new Effect.Highlight(source_element, {startcolor: "#f0f0f0", endcolor: "#ffffff", duration: .5, queue:{position: 'end', scope: 'copyscope', limit: 1}})


#   copyPhrase(phrase_id) ->
#     phrases_clipboard = []
#     phrase_types_clipboard = []
#
#     element = $("phraseContent" + phrase_id)
#     if (element) {
#       phrases_clipboard.push(collectText(element))
#     }
#
#     element = $("phraseType" + phrase_id)
#     if (element) {
#       phrase_types_clipboard.push(element.value)
#     }
#
#     # Flash the row
#     source_element = $("phraseElement" + phrase_id)
#     new Effect.Highlight(source_element, {startcolor: "#ffffff", endcolor: "#f8f8f8", duration: .5, queue:{position: 'end', scope: 'copyphrasescope', limit: 1}})


  #
  # Copies multiple phrases to the clipboard.
  #
#   copyPhrases(item_id) ->
#     phrases_clipboard = []
#     phrase_types_clipboard = []
#
#     # Texts
#     elements = $$("#phrases" + item_id + " .phraseContent")
#     for (i = 0; i < elements.length; i++) {
#       if (elements[i].firstChild) {
#         phrases_clipboard.push(collectText(elements[i]))
#       }
#     }
#
#     # Types
#     elements = $$("#phrases" + item_id + " .phraseType")
#     for (i = 0; i < elements.length; i++) {
#       if (elements[i]) {
#         phrase_types_clipboard.push(elements[i].value)
#       }
#     }
#
#     # Flash the table
#     source_element = $("phrases" + item_id)
#     new Effect.Highlight(source_element, {startcolor: "#ffffff", endcolor: "#f8f8f8", duration: .5, queue:{position: 'end', scope: 'copyphrasescope', limit: 1}})

#   copyItem(item_id) ->
#     copyPhrases(item_id)
#     copyItemGrades(item_id)


#   pasteItemGrades(item_id) ->
#     # Take the texts from the clipboard
#     parameters = ""
#     for (i = 0; i < texts_clipboard.length; i++) {
#       parameters += "&text[" + i + "]" + "=" + encodeURIComponent(texts_clipboard[i])
#     }
#
#     # Make the Ajax call
#     new Ajax.Updater("item-grades" + item_id,
#         "<%= url_for :only_path => true, :action => 'new_item_grading_options' %>?iid=" + item_id + parameters,
#         { asynchronous:true,
#           evalScripts:true,
#           parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
#         }
#       )


#   pasteSectionGrades(section_id) ->
#     # Take the texts from the clipboard
#     parameters = ""
#     for (i = 0; i < texts_clipboard.length; i++) {
#       parameters += "&text[" + i + "]" + "=" + encodeURIComponent(texts_clipboard[i])
#       parameters += "&points[" + i + "]" + "=" + encodeURIComponent(points_clipboard[i])
#     }
#
#     # Make the Ajax call
#     new Ajax.Updater("section-grades" + section_id,
#         "<%= url_for :only_path => true, :action => 'new_section_grading_options' %>?sid=" + section_id + parameters,
#         { asynchronous:true,
#           evalScripts:true,
#           parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
#         }
#       )


#   pastePhrases(item_id) ->
#     # Take the texts from the clipboard
#     parameters = ""
#     for (i = 0; i < phrases_clipboard.length; i++) {
#       parameters += "&text[" + i + "]" + "=" + encodeURIComponent(phrases_clipboard[i])
#       parameters += "&type[" + i + "]" + "=" + encodeURIComponent(phrase_types_clipboard[i])
#     }
#
#     # Make the Ajax call
#     new Ajax.Updater("phrases" + item_id,
#         "<%= url_for :only_path => true, :action => 'new_phrases' %>?iid=" + item_id + parameters,
#         { asynchronous:true,
#           evalScripts:true,
#           parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
#         }
#       )
