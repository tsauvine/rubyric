#= require annotationEditor

jQuery ->
  rawRubric = $('#rubric_payload').val()
  rubric = $.parseJSON(rawRubric) if rawRubric.length > 0

  rawReview = $('#review_payload').val()
  review = $.parseJSON(rawReview) if rawReview.length > 0

  new AnnotationEditor(rubric, review)
