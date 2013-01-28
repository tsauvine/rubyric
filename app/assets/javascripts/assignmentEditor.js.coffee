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
    @assignments = ko.observableArray()  # TODO: load from server

  #removeAssignment: (group) ->
    

class Group
  constructor: (data, users) ->
    @id = data['id']
    @selected = ko.observable(false)

    @students = []
    for user_id in data['user_ids']
      @students.push(users[user_id])

    @reviewers = ko.observableArray()

  assignTo: (reviewer) ->
    @reviewers.push(reviewer)
    reviewer.assignments.push(this)

  removeAssignment: (reviewer) ->
    console.log this
    @reviewers.remove(reviewer)
    reviewer.assignments.remove(this)
  
  clickAssign: () ->
    modal = $('#modalAssign')
    modal.data('group', this)
    modal.modal()

class AssignmentEditor
  constructor: (data) ->
    @currentReviewer = ko.observable()
    
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
  
  
  clickSelectAll: ->
    for group in @groups
      group.selected(true)
  
  
  clickSelectNone: ->
    for group in @groups
      group.selected(false)
  
  
  clickAssign: ->
    user = @users_by_id[@currentReviewer()]
    return unless user
    
    for group in @groups
     group.assignTo(user) if group.selected()
  
  clickModalAssign: (user) ->
    modal = $('#modalAssign')
    group = modal.data('group')
    console.log group
    console.log user
    return unless group
  
    group.assignTo(user)
    
    modal.modal('hide')
    

jQuery ->
  $.getJSON $('#groups').data('url'), (data) ->
    assignmentEditor = new AssignmentEditor(data)
    ko.applyBindings(assignmentEditor)
    $('#groups').removeClass('busy')
