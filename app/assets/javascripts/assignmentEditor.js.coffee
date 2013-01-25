#= require handlebars-1.0.0.beta.6.js
#= require knockout-2.2.1

class Group
  constructor: (data) ->
    @id = ko.observable(data['id'])

    @students = []
    for row in data['users']
      @students.push
        name: "#{row['firstname']} #{row['lastname']}"
        studentnumber: row['studentnumber']

    @reviewers = ko.observableArray(groups)

class AssignmentEditor
  constructor: (data) ->
    groups = []
    for row in data
      group = new Group(row)
      groups.push(group)
  
    @groups = ko.observableArray(groups)
 
jQuery ->

  $.getJSON $('#groups').data('url'), (data) ->
    assignmentEditor = new AssignmentEditor(data)
    ko.applyBindings(assignmentEditor)
  