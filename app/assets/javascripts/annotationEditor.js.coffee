#= require knockout-2.2.1
#= require bootstrap

class SubmissionPage
  constructor: (url) ->
    @src = ko.observable('')
    @alt = ko.observable('')
  
  loadPage: (page_number) ->
    console.log "Loading page #{page_number}"
    img = @imgs[page_number]
    console.log img
    
    img.attr 'onLoad', => @loadPage(page_number + 1) if page_number < @page_count - 1
    
    @src("#{@submission_url}?page=#{page_number}&zoom=#{@zoom}")
    
    
    console.log "setting img src: " + url
    img.attr 'src', url
  

class AnnotationEditor
  constructor: () ->
    @element = $('#annotation-editor')
    
    #@review = new Review()
    #@review.loadRubric($('#annotation-editor').data('rubric-url'))
    
    # TODO: @review.loadReview($('#annotation-editor').data('review-url'))
    
    @page_count = @element.data('page-count')
    @zoom = 1.0
    @imgs = []
    @page_divs = []
    
    @submission_pages = []
  
    # Load PDF
    this.loadSubmission()
  
    ko.applyBindings(this)

  
  loadSubmission: ->
    @submission_url = $('#annotation-editor').data('submission-url')
    
    # Create dom
    for i in [0...@page_count]
      page = new SubmissionPage()
      @submission_pages.push(page)
      
      
      div = $('<div>')
      img = $('<img>')
      div.width 612 * 1.5
      img.width 612 * 1.5
      img.height 792 * 1.5
      div.append(img)
      @element.append(div)
      @page_divs.push(div)
      @imgs.push(img)

    this.loadPage(0)
  
  clickFinish: ->
    this.save()

    # TODO: redirect
  
  renderRubric: ->
    for page in @review.pages
      page.addToDom()


jQuery ->
  new AnnotationEditor
