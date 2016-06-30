#= require jquery.grumble.min
#= require jquery.crumble
#= require reviewEditor

jQuery ->
  rawRubric = $('#rubric_payload').val()
  rubric = $.parseJSON(rawRubric) if rawRubric.length > 0
  
  editor = new ReviewEditor(rubric)
  editor.loadReview()
  
  #$('#tour').crumble()
