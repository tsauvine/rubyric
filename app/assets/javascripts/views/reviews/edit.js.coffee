#= require jquery.grumble.min
#= require jquery.crumble
#= require reviewEditor

jQuery ->
  editor = new ReviewEditor()

  rawRubric = $('#rubric_payload').val()
  rubric = $.parseJSON(rawRubric) if rawRubric.length > 0
  editor.parseRubric(rubric)

  editor.loadReview()
  
  $('#tour').crumble()
