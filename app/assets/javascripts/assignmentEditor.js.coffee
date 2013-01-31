#= require handlebars-1.0.0.beta.6.js
#= require knockout-2.2.1
#= require bootstrap

class User
  constructor: (data) ->
    @id = data['id']
    @firstname = data['firstname']
    @lastname = data['lastname']
    @name = "#{@firstname} #{@lastname}"
    @studentnumber = data['studentnumber']
    @assignments = ko.observableArray()
    

class Group
  constructor: (data, users) ->
    @id = data['id']
    @selected = ko.observable(false)

    # Set students
    @students = []
    groupname = []
    for user_id in data['user_ids']
      student = users[user_id]
      @students.push(student)
      groupname.push(student.name + ' (' + student.studentnumber + ')')
      
    @name = groupname.join(', ')

    # Set reviewers
    @reviewers = ko.observableArray()
    for user_id in data['reviewer_ids']
      reviewer = users[user_id]
      @reviewers.push(reviewer)
      reviewer.assignments.push(this)
    

  assignTo: (reviewer) ->
    return if @reviewers.indexOf(reviewer) >= 0 # Ignore duplicates
    
    @reviewers.push(reviewer)
    reviewer.assignments.push(this)

  removeAssignment: (reviewer) ->
    @reviewers.remove(reviewer)
    reviewer.assignments.remove(this)
  
  clickAssign: () ->
    modal = $('#modalAssign')
    modal.data('group', this)
    modal.modal()


class AssignmentEditor
  constructor: (data) ->
    @currentReviewer = ko.observable()
    @testi = ko.observable('testi')
    
    @users_by_id = {}
    @teachers = []
    @assistants = []
    @reviewers = []  # = @teachers + @assistants
    @groups = []
    
    for user in data['users']
      @users_by_id[user.id] = new User(user)
    
    for user_id in data['teachers']
      @teachers.push(@users_by_id[user_id])
      @reviewers.push(@users_by_id[user_id])
    
    for user_id in data['assistants']
      @assistants.push(@users_by_id[user_id])
      @reviewers.push(@users_by_id[user_id])
    
    for group in data['groups']
      @groups.push(new Group(group, @users_by_id))
  
    # Event handlers
    $(document).on('click', '.removeAssignment', @removeAssignment)
    #$(window).bind 'beforeunload', => return "You have unsaved changes. Leave anyway?" unless @saved
  
  
  clickSelectAll: ->
    for group in @groups
      group.selected(true)
  
  
  clickSelectNone: ->
    for group in @groups
      group.selected(false)
  
  
  clickAssign: ->
    if @currentReviewer() == 'assistants'
      users = @assistants
    else if @currentReviewer() == 'evenly'
      users = @reviewers
    else
      user = @users_by_id[@currentReviewer()]
      return unless user
      users = [user]
      
    return if users.length < 1
    
    index = 0
    for group in @groups
      continue unless group.selected()
      group.assignTo(users[index])
      index++
      index = 0 if index >= users.length
  
  
  clickModalAssign: (user) ->
    modal = $('#modalAssign')
    group = modal.data('group')
    return unless group
  
    group.assignTo(user)
    
    modal.modal('hide')
  
  
  removeAssignment: ->
    group = ko.contextFor(this).$parent
    reviewer = ko.dataFor(this)
    
    group.removeAssignment(reviewer)
    
    return false
  
  
  clickSave: ->
    assignments = {}
    
    for group in @groups
      assignments[group.id] = []
      for reviewer in group.reviewers()
        assignments[group.id].push(reviewer.id)
  
  
    $('#save-button').addClass('busy')
    url = $('#assign-groups').data('url')
    
    $.ajax
      type: "PUT"
      url: url
      data: JSON.stringify({assignments: assignments})
      contentType: 'application/json'
      dataType: 'json'
      error: (error) ->
        $('#save-button').removeClass('busy')
        #alert("Failed to save")
      success: -> $('#save-button').removeClass('busy')
      


jQuery ->
  $.getJSON $('#assign-groups').data('url'), (data) ->
    assignmentEditor = new AssignmentEditor(data)
    ko.applyBindings(assignmentEditor)
    $('#assign-groups').removeClass('busy')
