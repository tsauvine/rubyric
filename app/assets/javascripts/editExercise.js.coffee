#= require jquery.ui.all
#= require jquery-ui-timepicker-addon

jQuery ->
  $('#exercise_deadline').datetimepicker(dateFormat: 'yy-mm-dd', timeFormat: 'hh:mm')
