#= require bootstrap.js

jQuery ->
  # Attach event listeners
  $('#reviews-select-all').click(-> $('#submissions_table input.review_check').each((i, element) -> element.checked = true ))
  $('#reviews-select-finished').click(-> $('#submissions_table input.review_check_finished').each((i, element) -> element.checked = true; ))
  $('#reviews-select-none').click(-> $('#submissions_table input.review_check').each((i, element) -> element.checked = false))
