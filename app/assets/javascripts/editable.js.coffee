ko.bindingHandlers.editable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    value = valueAccessor()

    $(element).mousedown (event) ->
      value.clickStartPos = {x: event.pageX, y: event.pageY}
    
    $(element).mouseup (event) ->
      clickStartPos = value.clickStartPos
      xDist = event.pageX - clickStartPos.x
      yDist = event.pageY - clickStartPos.y
      dist = xDist * xDist + yDist * yDist
      
      # Activate editor unless dragging
      value.editorActive(true) if dist < 25
  
  
  update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    options = valueAccessor()
    el = $(element)

    # Edit or display?
    if ko.utils.unwrapObservable(options.editorActive)
      # Edit
      type = ko.utils.unwrapObservable(options.type) || 'textfield'
      original_value = ko.utils.unwrapObservable(options.value)
      
      if original_value?
        shown_value = original_value.toString().replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
      else
        shown_value = ''
      
      #ko.utils.registerEventHandler element, "change", () ->
      #  observable = editorActive;
      #  observable($(element).datepicker("getDate"));
    
      # Create editor
      inputPlaceholder = ko.utils.unwrapObservable(options.inputPlaceholder)
      if inputPlaceholder?
        inputPlaceholderHtml = " placeholder='#{inputPlaceholder}'"
      else
        inputPlaceholderHtml = ''
      
      if 'textarea' == type
        input = $("<textarea#{inputPlaceholderHtml}>#{shown_value}</textarea>")
      else
        input = $("<input type='textfield'#{inputPlaceholderHtml} value='#{shown_value}' />")

      # Event handlers
      okHandler = (event) =>
        options.value(new String(input.val()))
        options.editorActive(false)
        event.stopPropagation()

      cancelHandler = (event) ->
        options.value(new String(original_value))
        options.editorActive(false)
        event.stopPropagation()

      # Make buttons
      ok = $('<button>OK</button>').click(okHandler)
      cancel = $('<button>Cancel</button>').click(cancelHandler)

      # Attach event handlers
      input.keyup (event) ->
        switch event.keyCode
          when 13
            okHandler(event) unless type == 'textarea'
          when 27 then cancelHandler(event)

        # Prevent esc from closing the dialog
        event.stopPropagation()

      # Close on blur
      #input.blur(cancelHandler)

      # Stop propagation of clicks to prevent reopening the editor when clicking the input
      input.click (event) -> event.stopPropagation()

      # Replace original text with the editor
      el.empty()
      el.append(input)
      el.append('<br />') if 'textarea' == type
      el.append(ok)
      el.append(cancel)

      # Set focus to the editor
      input.focus()
      input.select()

      # handle disposal (if KO removes by the template binding)
      #ko.utils.domNodeDisposal.addDisposeCallback(element, () ->
        # TODO
        #$(element).editable("destroy")
      #)
    
    else
      # Display
      placeholder = ko.utils.unwrapObservable(options.placeholder) || '-'
      value = ko.utils.unwrapObservable(options.value)
      
      if value?
        value = value.toString()
      else
        value = ''
      
      # Show placeholder if value is empty
      value = placeholder if placeholder && value.length < 1
      
      # Escape nasty characters
      value = value.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')

      el.html(value)
}
