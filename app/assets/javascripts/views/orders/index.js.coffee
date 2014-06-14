#= require jquery.ui.slider 

updatePrice = (students) ->
  return if isNaN(students) || !students
  unitPrice = 0.50
  freeStudents = 20
  maxStudents = 1000
   # $("#slider-students").slider("value")
  
  paidStudents = students - freeStudents
  paidStudents = 0 if paidStudents < 0
  price = Math.floor(paidStudents * unitPrice)
  
  if students <= maxStudents
    $("#price").text(price)
  else
    $("#price").text('')
  

jQuery ->
  $("#slider-students").slider
    orientation: "horizontal",
    range: "min",
    min: 20,
    max: 1000,
    value: 20,
    step: 10,
    slide: (event, ui) ->
      students = ui.value
      $("#students").val(students)
      updatePrice(students)
  
  $("#students").on('input', () ->
                    students = parseInt($("#students").val())
                    updatePrice(students)
  )