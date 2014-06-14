#= require jquery.ui.slider 

updatePrice = ->
  unitPrice = 0.1
  freeAssessments = 100
  assignments = $("#slider-assignments").slider("value")
  students = $("#slider-students").slider("value")
  assessments = students * assignments
  
  paidAssessments = assessments - freeAssessments
  paidAssessments = 0 if paidAssessments < 0
  price = Math.floor(paidAssessments * unitPrice)
  
  $("#assignments").val(assignments)
  $("#students").val(students)
  $("#assessments").val(assessments)
  $("#price").val(price)

jQuery ->
  $("#slider-assignments").slider
    orientation: "vertical",
    range: "min",
    min: 1,
    max: 5,
    value: 3,
    slide: updatePrice
    #slide: (event, ui) ->
    #  $("#assignments").val(ui.value)
  
  $("#slider-students").slider
    orientation: "horizontal",
    range: "min",
    min: 10,
    max: 1000,
    value: 50,
    step: 10,
    slide: updatePrice
  
  updatePrice()
  
  
  