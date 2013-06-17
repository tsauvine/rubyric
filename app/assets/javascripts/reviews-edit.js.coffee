#= require reviewEditor

jQuery ->
  editor = new ReviewEditor()
  
  rubric_url = $('#review-editor').data('rubric-url')
  
  editor.loadRubric rubric_url, ->
    editor.loadReview()
 