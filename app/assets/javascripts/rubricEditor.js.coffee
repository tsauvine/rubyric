# texts_clipboard = [];
# points_clipboard = [];
# phrases_clipboard = [];
# phrase_types_clipboard = [];

class Page
  constructor: (@rubricEditor, @id) ->
    @criteria = []

  initializeDefault: () ->
    @name = 'New page'
    criterionId = @rubricEditor.nextCriterionId()
    criterion = new Criterion(@rubricEditor, criterionId)
    @rubricEditor.criteriaById[criterionId] = criterion
    @criteria.push(criterion)
    criterion.initializeDefault()

  createDom: () ->
    html = @rubricEditor.pageTemplate({id: @id, name: @name})
    root = $(html)
    rubric = root.find('.rubric')

    for criterion in @criteria
      rubric.append(criterion.createDom())

    return root


class Criterion
  constructor: (@rubricEditor, @id) ->
    @name = ''
    @phrases = []
    @editorActive = false

  initializeDefault: () ->
    @name = 'Criterion'
    #@phrases.push(new Phrase(@rubricEditor, @rubricEditor.nextPhraseId(), "What went well"))
    #@phrases.push(new Phrase(@rubricEditor, @rubricEditor.nextPhraseId(), "What could be improved"))

  createDom: () ->
    dom = $(@rubricEditor.criterionTemplate({criterionId: @id, criterionName: @name, phrases: [{id: 1, content: "Kukkuu"}]}))
    @nameElement = dom.find('span.criterion')
    @nameElement.click($.proxy(@activateEditor, this))

    return dom

  activateEditor: ->
    console.log "Activate Criterion editor"

    return if @editorActive || !@nameElement
    @editorActive = true

    okButton = $("<button>OK</button>")
    cancelButton = $("<button>Cancel</button>")
    @textfield = $("<input type='text' value='#{@name}' />")

    okButton.click($.proxy(@save, this))
    cancelButton.click($.proxy(@closeEditor, this))

    @nameElement.empty()
    @nameElement.append(@textfield)
    @nameElement.append(okButton)
    @nameElement.append(cancelButton)

    @textfield.focus()

  closeEditor: ->
    console.log "Close Criterion editor"

    return unless @nameElement
    @nameElement.html(@name)
    @editorActive = false

  save: ->
    console.log "Save Criterion"
    @name = @textfield.val() if @textfield

    this.closeEditor()

class Phrase
  constructor: (@rubricEditor, @id, @content) ->
    @content = '' unless @content
    @editorActive = false

  createDom: () ->
    dom = $(@rubricEditor.phraseTemplate({id: @id, content: @content}))
    @tdElement = dom.find("td.phrase")
    @tdElement.click($.proxy(@activateEditor, this))

    return dom

  activateEditor: ->
    return if @editorActive || !@tdElement

    @editorActive = true

    okButton = $("<button>OK</button>")
    cancelButton = $("<button>Cancel</button>")
    @textarea = $("<textarea rows='3'>#{@content}</textarea><br />")

    okButton.click($.proxy(@savePhrase, this))
    cancelButton.click($.proxy(@closeEditor, this))

    @tdElement.empty()
    @tdElement.append(@textarea)
    @tdElement.append(okButton)
    @tdElement.append(cancelButton)

    @textarea.focus()

  closeEditor: ->
    return unless @tdElement
    @tdElement.html(@content)
    @editorActive = false

  savePhrase: ->
    @content = @textarea.val() if @textarea

    this.closeEditor()


class RubricEditor

  constructor: () ->
    @phraseEditableParams = {
      type: 'textarea',
      rows: 3,
      onblur: 'ignore',
      submit: 'Save',
      cancel: 'Cancel'
    }

    # Handlebar templates
    @pageTemplate = Handlebars.compile($("#page-template").html());
    @criterionTemplate = Handlebars.compile($("#criterion-template").html());
    @phraseTemplate = Handlebars.compile($("#phrase-template").html());

    @pages = []

    # Indexes
    @pagesById = {}
    @criteriaById = {}
    @phrasesById = {}

    @pageIdCounter = 0
    @criterionIdCounter = 0
    @phraseIdCounter = 0

    # Register event listeners
    $('#create-page').click($.proxy(@pageCreate, this))

#     $(".edit-criterion-button").live('click', $.proxy(@criterionEdit, this))
    $(".create-criterion-button").live('click', $.proxy(@criterionCreate, this))
#     $(".delete-criterion-button").live('click', $.proxy(@criterionDelete, this))
#
    $(".create-phrase-button").live('click', $.proxy(@phraseCreate, this))
#     $(".edit-phrase-button").live('click', $.proxy(@phraseEdit, this))
#     $(".delete-phrase-button").live('click', $.proxy(@phraseDelete, this))



  nextPageId: () ->
    return @pageIdCounter++

  nextCriterionId: () ->
    return @criterionIdCounter++

  nextPhraseId: () ->
    return @phraseIdCounter++


  registerListeners: ->
    $("td.phrase").editable(rubricEditorView.phraseSave, rubricEditorView.phraseEditableParams)

    $("span.criterion").editable(rubricEditorView.phraseSave, {
        type: 'text',
        onblur: 'ignore',
        submit: 'Save',
        cancel: 'Cancel'
      })

    $(".edit-phrase-button").click(rubricEditorView.editPhrase)

    $(".grading-options ul").sortable()

    # Quality levels are sortable
    $(".grading-options").sortable({containment: 'parent'})

    # Criteria are sortable
    $("#rubric").sortable(
      # TODO: {containment: '#page'}
    )

    # Phrases are sortable
    $("table.phrases tbody").sortable({
      containment: '#rubric',
      axis: 'y',
      connectWith: "table.phrases tbody"
    })

    # Criteria can be dropped to section links
    $(".section-name").droppable({
      accept: '.criterion',
      hoverClass: 'dropHover',
      drop: rubricEditorView.dropCriterionToSection,
      tolerance: 'pointer'
    })

  #
  # Loads rubric by AJAX
  #
  load: (url) ->

  #
  # Creates a new rubric page
  #
  pageCreate: ->
    pageId = this.nextPageId()
    page = new Page(this, pageId )
    page.initializeDefault()
    @pages.push(page)
    @pagesById[pageId] = page

    # Add tab
    $('#create-page-tab').before("<li><a href='#page-#{page.id}' data-toggle='tab'>#{page.name}</a></li>")

    # Add tab content
    $('#tab-contents').append(page.createDom())

  #
  # Creates a new criterion
  #
  criterionCreate: (event) ->
    pageId = $(event.target).data('page-id')

    # Create criterion object
    criterionId = this.nextCriterionId()
    criterion = new Criterion(this, criterionId)

    # Add to index
    @criteriaById[criterionId] = criterion

    # Add to criterion model
    page = @pagesById[pageId]
    page.criteria.push(criterion)

    # Add to DOM
    rubricDiv = $('#rubric-' + pageId)
    rubricDiv.append(criterion.createDom())

    criterion.activateEditor()

  #
  # Creates a new phrase
  #
  phraseCreate: (event) ->
    criterionId = $(event.target).data('criterion-id')

    # Create phrase object
    phraseId = this.nextPhraseId()
    phrase = new Phrase(this, phraseId)

    # Add to index
    @phrasesById[phraseId] = phrase

    # Add to criterion model
    criterion = @criteriaById[criterionId]
    criterion.phrases.push(phrase)

    # Add to DOM
    phrasesTable = $('#phrases-' + criterionId)
    phrasesTable.append(phrase.createDom())

    phrase.activateEditor()
#     contentTd.editable(rubricEditorView.phraseSave, rubricEditorView.phraseEditableParams)
#     contentTd.trigger('click')


  criterionEdit: (event) ->
    targetId = $(this).data('target-id')
    $('#' + targetId).trigger('click')


  # Activates a phrase editor
  phraseEdit: (event) ->
    tr = $(this).parents('tr')[0]
    $(tr).find('.phrase').trigger('click')


  criterionDelete: (event) ->
    tr = $(this).parents('tr')[0]
    tr.remove()


  # Removes the phrase td from the table.
  phraseDelete: (event) ->
    tr = $(this).parents('tr')[0]
    $(tr).remove()


  phraseSave: (value, settings) ->
    console.log(this)
    console.log(value)
    console.log(settings)
    return(value)


  dropCriterionToSection: (event, ui) ->
    draggable = ui.draggable
    draggable.effect('transfer', { to: $(this), className: "ui-effects-transfer" }, 500)
    draggable.remove()



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
