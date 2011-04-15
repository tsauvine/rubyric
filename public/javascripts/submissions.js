// submissions-select-all
// $$('#submissions_form input.submission_check').each(function(box){box.checked=true});return false;

// submissions-select-latest
// $$('#submissions_form input.submission_check_latest').each(function(box){box.checked=true});return false;

// submissions-select-none
// $$('#submissions_form input.submission_check').each(function(box){box.checked=false});return false;

// reviews-select-all
// $$('#submissions_form input.review_check').each(function(box){box.checked=true});return false;

// reviews-select-finished
// $$('#submissions_form input.review_check_finished').each(function(box){box.checked=true});return false;

// reviews-select-none
// $$('#submissions_form input.review_check').each(function(box){box.checked=false});return false;


$(document).ready(function(){
  // Attach event listeners
  $('#submissions-select-all').click(function(){$('#submissions_form input.submission_check').each(function(i, element){ element.checked = true; })});
  $('#submissions-select-latest').click(function(){$('#submissions_form input.submission_check_latest').each(function(i, element){ element.checked = true; })});
  $('#submissions-select-none').click(function(){$('#submissions_form input.submission_check').each(function(i, element){ element.checked = false; })});
  $('#reviews-select-all').click(function(){$('#submissions_form input.review_check').each(function(i, element){ element.checked = true; })});
  $('#reviews-select-finished').click(function(){$('#submissions_form input.review_check_finished').each(function(i, element){ element.checked = true; })});
  $('#reviews-select-none').click(function(){$('#submissions_form input.review_check').each(function(i, element){ element.checked = false; })});
});
