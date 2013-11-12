#= require jquery.ui.draggable
#= require jquery.ui.droppable
#= require knockout-2.2.1
#= require reviewEditor
#= require editable

ko.bindingHandlers.onload = {
  init: (element, valueAccessor, bindingHandlers, viewModel) ->
    callback = ko.utils.unwrapObservable(valueAccessor())
    
    $(element).bind 'load', ->
      callback.call(viewModel)
}

# Custom KnockOut binding for the jQuery UI draggable
ko.bindingHandlers.draggable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
    startCallback = valueAccessor().start
    stopCallback = valueAccessor().stop

    dragOptions = {
      distance: 5
      cursor: 'default'
      cursorAt: { left: 40, top: 5 }
      zIndex: 100
      appendTo: "body"
      helper: -> $('<div class="annotation-drag-helper"></div>')
    }

    dragOptions['start'] = (-> startCallback.call(viewModel)) if startCallback
    dragOptions['stop'] = (-> stopCallback.call(viewModel)) if stopCallback

    $(element).draggable(dragOptions).disableSelection()
    
}


# Custom KnockOut binding for the jQuery UI droppable
ko.bindingHandlers.droppable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
    dropCallback = valueAccessor().drop
    
    dropOptions = {
      tolerance: 'touch'
      accept: 'tr.phrase'
      drop: (event, ui) ->
        dragObject = ko.dataFor(ui.draggable.get(0))
        dropCallback(viewModel, dragObject, event, ui)
    }

    $(element).droppable(dropOptions)
}


# Custom KnockOut binding that makes it possible to move DOM objects.
# Usage:
# data-bind="position: position"
# @position = ko.observable({x: 0, y: 0})
#
# pos = @position()
# pos.x = 10
# pos.updated = false
# @position.valueHasMutated()
ko.bindingHandlers.position = {
  init: (element, valueAccessor, bindingHandlers, viewModel) ->
#     pos = $(element).position()
#     value = ko.utils.unwrapObservable(valueAccessor())
#     value.x = pos.left if value.x?
#     value.y = pos.top if value.y?
#     value.width = pos.width if value.width?
#     value.height = pos.height if value.height?

    dragOptions = {
      #containment: 'parent'
      distance: 5
      cursor: 'default'
    }

    #dragOptions['start'] = (-> startCallback.call(viewModel)) if startCallback
    dragOptions['stop'] = ->
      # Update model after drag and notify observers
      pos = $(element).position()
      value = ko.utils.unwrapObservable(valueAccessor())
      value.x = pos.left
      value.y = pos.top
      valueAccessor().valueHasMutated()
      
      # stopCallback.call(viewModel)) if stopCallback

    el = $(element)
    el.draggable(dragOptions).disableSelection()
    

  update: (element, valueAccessor, bindingHandlers, viewModel) ->
    value = ko.utils.unwrapObservable(valueAccessor())

    # Return if DOM is already up to date.
    # (Knockout calls update of all bindings if one binding changes which would
    # cause unwanted position updates for example, during a drag.)
    return if value['updated']
    
    el = $(element)
    options = {}
    options['left'] = value.x if value.x?
    options['top'] = value.y if value.y?
    options['width'] = value.width if value.width?
    options['height'] = value.height if value.height?

    el.css(options)
    #el.animate(options, 150)
    
    value['updated'] = true
}

class CreateAnnotationCommand
  constructor: (@page, options) ->
    @annotation = new Annotation(options)
    @page.annotations.push(@annotation)
    @annotation.contentEditorActive(true) if options['activateEditor']
  
  undo: ->
    @page.annotations.remove(@annotation)
  
  as_json: ->
    return if @annotation.deleted  # Deleted new Annotations can be ignored
    
    {
      command: 'create_annotation'
      submission_page_number: @annotation.submissionPage.pageNumber
      phrase_id: if @annotation.phrase then @annotation.phrase.id else undefined
      content: @annotation.content()
      grade: @annotation.grade()
      page_position: @annotation.pagePosition()
    }
  
class DeleteAnnotationCommand
  constructor: (@annotation) ->
    @annotation.submissionPage.annotations.remove(@annotation)
    @annotation.deleted = true
  
  undo: ->
    @annotation.submissionPage.annotations.push(@annotation)
    @annotation.deleted = false
  
  as_json: ->
    return unless @annotation.id?  # Deletions of new Annotations can be ignored
  
    {
      command: 'delete_annotation'
      id: @annotation.id
    }

class ModifyAnnotationCommand
  constructor: (@annotation, @change) ->
  
  undo: ->
  
  as_json: ->
    return if !@annotation.id? || @annotation.deleted   # Modifications to new Annotations can be ignored because the final values are saved anyway
    
    @change['command'] = 'modify_annotation'
    @change['id'] = @annotation.id
    return @change
    

class CommandBuffer
  constructor: ->
    @buffer = []
  
  as_json: ->
    array = []
    for command in @buffer
      json = command.as_json()
      array.push(json) if json
    
    return array


class SubmissionPage
  constructor: (@annotationEditor, @pageNumber) ->
    # TODO: get width from server. Now A4 is assumed.
    @width = ko.observable("#{Math.round(612 * 1.5)}px")
    @height = ko.observable("#{Math.round(792 * 1.5)}px")
    @src = ko.observable()
    @alt = ko.observable("Page #{@pageNumber + 1}")
    @nextPage = undefined
    
    @annotations = ko.observableArray()
    
  
  loadPage: () ->
    url = "#{@annotationEditor.submission_url}?page=#{@pageNumber}&zoom=#{@annotationEditor.zoom}"
    @src(url)
  
  # Called after image has been loaded
  onLoad: () ->
    # TODO: load when scrolling
    @nextPage.loadPage() if @nextPage

  clickCreateAnnotation: (submissionPage, event) =>
    currentTarget = event.currentTarget
    element = $('#submission-pages')
    scrollTop = element.scrollTop()
    scrollLeft = element.scrollLeft()

    options = {
      submissionPage: this
      content: ''
      grade: undefined
      screenPosition: {x: event.pageX - currentTarget.offsetLeft + scrollLeft, y: event.pageY - currentTarget.offsetTop + scrollTop}
      zoom: @annotationEditor.zoom
      activateEditor: true
    }
    
    this.createAnnotation(options)
    
  
  createAnnotation: (options) ->
    command = new CreateAnnotationCommand(this, options)
    @annotationEditor.addCommand(command)
    @annotationEditor.subscribeToAnnotation(command.annotation)
    

  deleteAnnotation: (annotation) =>
    @annotationEditor.addCommand(new DeleteAnnotationCommand(annotation))
  
    
class Annotation
  constructor: (options) ->
    options ||= {}
    
    @id = options['id']
    @phrase = options['phrase']
    @submissionPage = options['submissionPage']
    @content = ko.observable(options['content'])
    @grade = ko.observable(options['grade'])
    
    @zoom = options.zoom || 1.0
    
    screenPosition = options['screenPosition']
    pagePosition = options['pagePosition']
    
    # Calculate screenPos from pagePos or vice versa if only one is given
    pagePosition = {x: screenPosition.x / @zoom, y: screenPosition.y / @zoom} if !pagePosition && screenPosition
    screenPosition = {x: pagePosition.x * @zoom, y: pagePosition.y * @zoom} if !screenPosition && pagePosition
    
    @pagePosition = ko.observable(pagePosition || {x: 0, y: 0})
    @screenPosition = ko.observable(screenPosition || {x: 0, y: 0})
    
    @gradeEditorActive = ko.observable(false)
    @contentEditorActive = ko.observable(false)
  
    # Subscribe to screen position changes to update pagePos after dragging.
    @screenPosition.subscribe =>
      screenPos = @screenPosition()
      pagePos = @pagePosition()
      pagePos.x = screenPos.x / @zoom
      pagePos.y = screenPos.y / @zoom
      @pagePosition.valueHasMutated()

  
  clickAnnotation: ->
    # Catch clicks and prevent bubbling


class AnnotationEditor extends Rubric
  constructor: () ->
    super()
    
    @element = $('#annotation-editor')
    @submission_url = @element.data('submission-url')
    @page_count = @element.data('page-count')
    
    @zoom = 1.0
    @submission_pages = ko.observableArray()
    @phrasesById = {}
    
    @commandBuffer = new CommandBuffer()
    
    this.createSubmissionPages()
    
    # reviewEditor features
    @saved = true
    @finalizing = ko.observable(false)
    @finalGrade = ko.observable()
    
    this.parseRubric(window.rubric)
    
    ko.applyBindings(this)
  
    this.parseReview(window.review)
  
  createSubmissionPages: ->
    previousPage = undefined
    for i in [0...@page_count]
      page = new SubmissionPage(this, i)
      @submission_pages.push(page)
      
      previousPage.nextPage = page if previousPage
      previousPage = page
    
    @submission_pages()[0].loadPage() if @submission_pages().length > 0
  
  
  parseReview: (data) ->
    data ||= {}
    
    for raw_annotation in (data['annotations'] || [])
      submission_page = @submission_pages()[raw_annotation['submission_page_number']]
      continue unless submission_page
      phrase = @phrasesById[raw_annotation['phrase_id']]
    
      options = {
        'id': raw_annotation['id']
        'submissionPage': submission_page
        'phrase': phrase
        'content': raw_annotation['content']
        'grade': raw_annotation['grade']
        'pagePosition': raw_annotation['page_position']
      }
    
      annotation = new Annotation(options)
      submission_page.annotations().push(annotation)
      this.subscribeToAnnotation(annotation)
    
    for submission_page in @submission_pages()
      submission_page.annotations.valueHasMutated()
  
  
  addCommand: (command) ->
    @commandBuffer.buffer.push(command)
  
  
  subscribeToAnnotation: (annotation) ->
    # Subscribe to modifications
    annotation.content.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {content: newValue}))
  
    annotation.grade.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {grade: newValue}))
    
    annotation.pagePosition.subscribe (newValue) =>
      this.addCommand(new ModifyAnnotationCommand(annotation, {page_position: newValue}))
    
    
  cancelFinalize: ->
    @finalizing(false)
  
  
  showNextPage: (page) ->
    if page.nextPage
      page.nextPage.showTab()
    else
      this.finish()
      #$('#tab-finish-link').tab('show')
    
    # TODO: scroll to top
    #window.scrollTo(0, 0)
  
  
  finish: ->
    return if @finalizing()  # Ignore if already finalizing
    
    @finalizing(true)
    
    # Calculate grade
    grades = @pages.map (page) -> page.grade()
    grade = @rubric.calculateGrade(grades)
    @finalGrade(grade)
  
  
  clickGrade: (phrase) =>
    phrase.criterion.setGrade(phrase) if phrase.grade?
    @saved = false
  
  
  clickPhrase: (phrase) =>
    # TODO: add annotation
    this.clickGrade(phrase)
  
  
  dropPhrase: (page, phrase, event, ui) =>
    offset = $(event.target).offset()
    
    options = {
      submissionPage: page
      phrase: phrase
      content: phrase.content
      grade: phrase.grade
      screenPosition: {x: ui.position.left - offset.left, y: ui.position.top - offset.top}
      zoom: @zoom
    }
    
    page.createAnnotation(options)
  

  printJson: ->
    console.log @commandBuffer.as_json()

  # Populates the HTML-form from the model. This is called just before submitting.
  save: ->
    # Encode review as JSON
    $('#review_payload').val(JSON.stringify(@commandBuffer.as_json()))
    @saved = true
    
    return true
    

jQuery ->
  new AnnotationEditor
