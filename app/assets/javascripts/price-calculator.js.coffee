#= require jquery.ui.slider 

class @PriceCalculator
  constructor: ->
    $("#slider-students").slider
      orientation: "horizontal",
      range: "min",
      min: 20,
      max: 1000,
      value: 20,
      step: 10,
      slide: (event, ui) =>
        students = ui.value
        $("#students").val(students)
        this.updatePrice(students)
    
    $("#students").on('input', () =>
                      students = parseInt($("#students").val())
                      this.updatePrice(students)
    )
    
    this.updatePrice(parseInt($("#students").val()))
    
  updatePrice: (studentCount) ->
    return if isNaN(studentCount) || !studentCount
    unitPrice = 0.99
    freeStudents = 20
    maxStudents = 1000
    # $("#slider-studentCount").slider("value")
    
    paidStudents = studentCount - freeStudents
    paidStudents = 0 if paidStudents < 0
    price = Math.round(paidStudents * unitPrice)
    
    #$('#create-course-button').attr('href', "/courses/new?students=#{studentCount}");
    
    
    if price < 1
      $("#price").text('FREE')
    else if studentCount <= maxStudents
      $("#price").text('€ ' + price)
    else
      $("#price").text('') 
