#= require reviewEditor

jQuery ->
  editor = new ReviewEditor()
  editor.parseRubric(window.rubric)
  editor.loadReview()
