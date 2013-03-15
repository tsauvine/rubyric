$(document).ready(function(){
  // Attach event listeners
  $('#reviews-select-all').click(function(){$('#submissions_table input.review_check').each(function(i, element){ element.checked = true; })});
  $('#reviews-select-finished').click(function(){$('#submissions_table input.review_check_finished').each(function(i, element){ element.checked = true; })});
  $('#reviews-select-none').click(function(){$('#submissions_table input.review_check').each(function(i, element){ element.checked = false; })});
});
