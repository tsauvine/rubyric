ko.bindingHandlers.editable = {
  init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
#     $(element).click ->
#       valueAccessor().editorActive(true)

    $(element).mousedown (event) ->
      valueAccessor().clickStartPos = {x: event.pageX, y: event.pageY}
    
    $(element).mouseup (event) ->
      clickStartPos = valueAccessor().clickStartPos
      xDist = event.pageX - clickStartPos.x
      yDist = event.pageY - clickStartPos.y
      dist = xDist * xDist + yDist * yDist
      
      # Activate editor unless dragging
      valueAccessor().editorActive(true) if dist < 25
  
  
  update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    options = valueAccessor()
    el = $(element)

    if ko.utils.unwrapObservable(options.editorActive)
      type = ko.utils.unwrapObservable(options.type) || 'textfield'
      original_value = ko.utils.unwrapObservable(options.value)
      
      #ko.utils.registerEventHandler element, "change", () ->
      #  observable = editorActive;
      #  observable($(element).datepicker("getDate"));
    
      # Create editor
      if 'textarea' == type
        input = $("<textarea>#{original_value}</textarea>")
      else
        input = $("<input type='textfield' value='#{original_value}' />")

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
      placeholder = ko.utils.unwrapObservable(options.placeholder) || '-'
      value = ko.utils.unwrapObservable(options.value)
      
      # Show placeholder if value is empty
      value = placeholder if placeholder && (!value || value.length < 1)
      
      # Escape nasty characters
      value = value.toString().replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br />')

      el.html(value)

}
