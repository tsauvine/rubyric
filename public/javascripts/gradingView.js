var modified = false;

/**
* Adds a phrase to a feedback textarea.
*/
function addFeedback(source, type) {
  // Raise the 'modified' flag to warn about unsaved changes
  modified = true;

  // Collect text. (There are multiple child elements if <br />s are present.)
  sourceElement = $(source);
  text = $A(sourceElement.childNodes).collect( function(node) {
    return (node.nodeType == 3 ? node.nodeValue.strip() : '\n');
  }).join('');

  // Select target text area
  switch (type) {
    case "Good":
      targetElement = $("feedback_good")
      caption = $("positiveCaption")
      color = "#a0ffa0"
      break;

    case "Bad":
      targetElement = $("feedback_bad")
      caption = $("negativeCaption")
      color = "#ffa0a0"
      break;

    case "Neutral":
      targetElement = $("feedback_neutral")
      caption = $("commentsCaption")
      color = "#c0c0ff"
      break;
  }

  if (targetElement) {
    targetElement.value += text + "\n";
  }

  // Flash the caption and hilight the phrase
  new Effect.Highlight(caption, {startcolor: color, endcolor: "#f8f8f8", duration: .6, queue: "end"});
  sourceElement.addClassName("bold");

  // Scroll down
  targetElement.scrollTop = targetElement.scrollHeight;

  return false;
}

/**
* Selects a grading option.
*/
function setGrade(item, grade, grading_option) {
  modified = true;

  // De-hilight the previous selection
  for (i = 0; ; i++) {
    element = $("grade" + item + "_" + i);
    if (!element) {
      break
    }

    element.removeClassName("selected")
  }

  //Hilight the new selection
  element = $("grade" + item + "_" + grade)
  element.addClassName("selected")

  // Update the hidden field
  hidden_field = $("item_grades_" + item)
  hidden_field.value = grading_option
}

