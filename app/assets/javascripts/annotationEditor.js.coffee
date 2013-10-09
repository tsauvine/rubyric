#= require jquery.ui.draggable
#= require knockout-2.2.1
#= require reviewEditor

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
      containment: 'parent'
      distance: 5
      cursor: 'default'
    }

    dragOptions['start'] = (-> startCallback.call(viewModel)) if startCallback
    dragOptions['stop'] = (-> stopCallback.call(viewModel)) if stopCallback

    $(element).draggable(dragOptions).disableSelection()
}


# Custom KnockOut binding for the jQuery UI droppable
ko.bindingHandlers.droppable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel) ->
    dropOptions = {
      tolerance: 'pointer',
      drop: (event, ui) ->
        dragObject = ko.dataFor(ui.draggable.get(0))
        valueAccessor()(dragObject)
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
# @position.valuesHasMutated()
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
    #dragOptions['stop'] = (-> stopCallback.call(viewModel)) if stopCallback

    $(element).draggable(dragOptions).disableSelection()

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

    #el.animate(options, 150)
    
    value['updated'] = true
}


class SubmissionPage
  constructor: (@annotationEditor, @pageNumber) ->
    @src = ko.observable()
    @alt = ko.observable('')
    @nextPage = undefined
    
    @annotations = ko.observableArray()
    annotation = new Annotation()
    annotation.content('Tämä on testi')
    @annotations.push(annotation)
    
  
  loadPage: () ->
    url = "#{@annotationEditor.submission_url}?page=#{@pageNumber}&zoom=#{@annotationEditor.zoom}"
    @src(url)
  
  # Called after image has been loaded
  onLoad: () ->
    @nextPage.loadPage() if @nextPage

class Annotation
  constructor: ->
    @screenPosition = ko.observable({x: 0, y: 0})
    @content = ko.observable('')

class AnnotationEditor extends Rubric
  constructor: () ->
    super()
    
    @element = $('#annotation-editor')
    
    @submission_url = $('#annotation-editor').data('submission-url')
    @page_count = @element.data('page-count')
    @zoom = 1.0
    @submission_pages = ko.observableArray()
    
    this.createSubmissionPages()
    
    
    # TODO: @review.loadReview($('#annotation-editor').data('review-url'))
    this.loadRubric $('#annotation-editor').data('rubric-url'), =>
      ko.applyBindings(this)
      @submission_pages()[0].loadPage() if @submission_pages().length > 0

  
  createSubmissionPages: ->
    previousPage = undefined
    for i in [0...@page_count]
      page = new SubmissionPage(this, i)
      @submission_pages.push(page)
      
      previousPage.nextPage = page if previousPage
      previousPage = page
    
#       div.width 612 * 1.5
#       img.width 612 * 1.5
#       img.height 792 * 1.5

  
  clickFinish: ->
    #this.save()

    
  #save: () ->
    

jQuery ->
  new AnnotationEditor
