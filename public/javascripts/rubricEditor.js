var texts_clipboard = [];  // For grades
var points_clipboard = [];

var phrases_clipboard = [];
var phrase_types_clipboard = [];


var rubricEditorView = {
  
  /**
   * Activates a phrase editor
   */
  editPhrase: function(event) {
    var targetId = $(this).data('target-id');
    var targetObject = $('#' + targetId);
    
    var currentText = jQuery.trim(targetObject.html());
    
    var textarea = $('<textarea></textarea>', {width: '100%', rows: 5});
    textarea.html(currentText);
    
    var okButton = $('<button>OK</button>').click({textarea: textarea}, rubricEditorView.savePhrase);
    
    targetObject.html(textarea);
    targetObject.append(okButton);
    
  },
  
  //savePhrase: function(event) {
  savePhrase: function(value, settings) {
    alert('kukkuu');
    //event.data.textarea.html('kukkuu');
    return(value);
  },
  
  dropCriterionToSection: function(event, ui) {
    draggable = ui.draggable;
    draggable.effect('transfer', { to: $(this), className: "ui-effects-transfer" }, 500);
    draggable.remove();
  }
};


$(document).ready(function(){
  
  $('.phraseContent').editable(rubricEditorView.savePhrase, {
    type: 'textarea',
    rows: 3,
    width: '100%',
    cancel: 'Cancel',
    submit: 'OK'
  });

  
  // Quality levels are sortable
  $(".grading-options").sortable({containment: 'parent'});

  // Criteria are sortable
  $("#rubric").sortable(
    // TODO: {containment: '#page'}
  );

  // Phrases are sortable
  $("table.phrases tbody").sortable({
    containment: '#rubric',
    axis: 'y',
    connectWith: "table.phrases tbody"
  });
 
//   $(".criterion").draggable({
//                 revert: 'invalid',
//                 helper: 'clone',
//                 //connectToSortable: '#rubric',
//   });

  
  // Criteria can be dropped to section links
  $(".section-name").droppable({
    accept: '.criterion',
    hoverClass: 'dropHover',
    drop: rubricEditorView.dropCriterionToSection,
    tolerance: 'pointer'
  });

});



// Ajax.InPlaceEditor.DefaultOptions.highlightColor =    'transparent';
// Ajax.InPlaceEditor.DefaultOptions.highlightEndColor = 'transparent';

/**
  * Collects and concatenates the text nodes under an element (non-recursively).
  * Other elements are replaced with '\n'. Returns a string.
  */
function collectText(element) {
  text = $A(element.childNodes).collect( function(node) {
    return (node.nodeType == 3 ? node.nodeValue.strip() : '\n');
  }).join('');
  return text;
}

/**
  * Copies item grading options to the clipboard.
  */
function copyItemGrades(item_id) {
  texts_clipboard = [];
  points_clipboard = [];

  // Push the text to the clipboard
  elements = $$("#item-grades" + item_id + " .itemGradingOption");
  for (i = 0; i < elements.length; i++) {
    if (elements[i].firstChild) {
      texts_clipboard.push(elements[i].firstChild.data);
      points_clipboard.push('0');
    }
  }

  // Flash the table
  source_element = $("item-grades" + item_id);
  new Effect.Highlight(source_element, {startcolor: "#f0f0f0", endcolor: "#ffffff", duration: .5, queue:{position: 'end', scope: 'copyscope', limit: 1}});
}

/**
  * Copies section grading options to the clipboard.
  */
function copySectionGrades(section_id) {
  // Push the text to the clipboard
  texts = $$("#section-grades" + section_id + " .sectionGradingText");
  points = $$("#section-grades" + section_id + " .sectionGradingPoints");
  texts_clipboard = [];
  points_clipboard = [];

  for (i = 0; i < texts.length; i++) {
    texts_clipboard.push(texts[i].firstChild.data);
    points_clipboard.push(points[i].firstChild.data);
  }

  // Flash the table
  source_element = $("section-grades" + section_id);
  new Effect.Highlight(source_element, {startcolor: "#f0f0f0", endcolor: "#ffffff", duration: .5, queue:{position: 'end', scope: 'copyscope', limit: 1}});
}

function copyPhrase(phrase_id) {
  phrases_clipboard = [];
  phrase_types_clipboard = [];

  element = $("phraseContent" + phrase_id);
  if (element) {
    phrases_clipboard.push(collectText(element));
  }

  element = $("phraseType" + phrase_id);
  if (element) {
    phrase_types_clipboard.push(element.value);
  }

  // Flash the row
  source_element = $("phraseElement" + phrase_id);
  new Effect.Highlight(source_element, {startcolor: "#ffffff", endcolor: "#f8f8f8", duration: .5, queue:{position: 'end', scope: 'copyphrasescope', limit: 1}});
}

/**
  * Copies multiple phrases to the clipboard.
  */
function copyPhrases(item_id) {
  phrases_clipboard = [];
  phrase_types_clipboard = [];

  // Texts
  elements = $$("#phrases" + item_id + " .phraseContent");
  for (i = 0; i < elements.length; i++) {
    if (elements[i].firstChild) {
      phrases_clipboard.push(collectText(elements[i]));
    }
  }

  // Types
  elements = $$("#phrases" + item_id + " .phraseType");
  for (i = 0; i < elements.length; i++) {
    if (elements[i]) {
      phrase_types_clipboard.push(elements[i].value);
    }
  }

  // Flash the table
  source_element = $("phrases" + item_id);
  new Effect.Highlight(source_element, {startcolor: "#ffffff", endcolor: "#f8f8f8", duration: .5, queue:{position: 'end', scope: 'copyphrasescope', limit: 1}});
}

function copyItem(item_id) {
  copyPhrases(item_id);
  copyItemGrades(item_id);
}

function pasteItemGrades(item_id) {
  // Take the texts from the clipboard
  parameters = "";
  for (i = 0; i < texts_clipboard.length; i++) {
    parameters += "&text[" + i + "]" + "=" + encodeURIComponent(texts_clipboard[i]);
  }

  // Make the Ajax call
  new Ajax.Updater("item-grades" + item_id,
      "<%= url_for :only_path => true, :action => 'new_item_grading_options' %>?iid=" + item_id + parameters,
      { asynchronous:true,
        evalScripts:true,
        parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
      }
    );
}

function pasteSectionGrades(section_id) {
  // Take the texts from the clipboard
  parameters = "";
  for (i = 0; i < texts_clipboard.length; i++) {
    parameters += "&text[" + i + "]" + "=" + encodeURIComponent(texts_clipboard[i]);
    parameters += "&points[" + i + "]" + "=" + encodeURIComponent(points_clipboard[i]);
  }

  // Make the Ajax call
  new Ajax.Updater("section-grades" + section_id,
      "<%= url_for :only_path => true, :action => 'new_section_grading_options' %>?sid=" + section_id + parameters,
      { asynchronous:true,
        evalScripts:true,
        parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
      }
    );
}

function pastePhrases(item_id) {
  // Take the texts from the clipboard
  parameters = "";
  for (i = 0; i < phrases_clipboard.length; i++) {
    parameters += "&text[" + i + "]" + "=" + encodeURIComponent(phrases_clipboard[i]);
    parameters += "&type[" + i + "]" + "=" + encodeURIComponent(phrase_types_clipboard[i]);
  }

  // Make the Ajax call
  new Ajax.Updater("phrases" + item_id,
      "<%= url_for :only_path => true, :action => 'new_phrases' %>?iid=" + item_id + parameters,
      { asynchronous:true,
        evalScripts:true,
        parameters:'authenticity_token=' + encodeURIComponent('<%= "#{form_authenticity_token}" %>')
      }
    );
}
