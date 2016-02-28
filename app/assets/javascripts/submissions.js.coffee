#= require bootstrap-3.1.1.min

jQuery ->
  # Attach event listeners
  $('#reviews-select-finished').click(-> $('#submissions_table input.review_check_finished').prop('checked', true))
  $('#reviews-select-all').click(-> $('#submissions_table input.review_check').prop('checked', true))
  $('#reviews-select-none').click(-> $('#submissions_table input.review_check').prop('checked', false))
