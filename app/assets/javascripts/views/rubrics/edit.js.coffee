#= require rubricEditor

jQuery ->
  rubricUrl = $('#rubric-editor').data('url')
  demoMode = $('#rubric-editor').data('demo')

  rawRubric = $('#rubric_payload').val()
  rubric = $.parseJSON(rawRubric) if rawRubric.length > 0

  new RubricEditor(rubric, rubricUrl, demoMode)
