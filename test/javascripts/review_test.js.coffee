#= require application
#= require reviewEditor

#fixture.preload("fixture.html", "fixture.json");

module "module",
  setup: ->
    #fixture.set("<h2>Another Title</h2>");
    #this.fixtures = fixture.load("fixture.html", "fixture.json", true);
    
    editor = new ReviewEditor()
    
    editor.parseRubric "{
      'version': '2',
      'pages': [
        {
          'id': 0,
          'name': 'Sivu 1',
          'criteria': [
            {
              'id':0, 
              'name':'Kriteeri 1.1',
              'phrases':[
                {'id':0, 'text':'Mikä meni hyvin\nToinen rivi', 'category':0, 'grade':5},
                {'id':1, 'text':'<b>Mikä meni huonosti</b>', 'category':1, 'grade': 'Hylätty'},
                {'id':8, 'text':'Jotain muuta','category':2}
              ]
            },
            {
              'id':1,
              'name':'Kriteeri 1.2',
              'phrases': [
                {'id':8,'text':'Olipa hyvä','category':0},
                {'id':8,'text':'Olipa huono','category':1}
              ]
            }
          ]
        },
      ],
      'grades': ['Failed',1,2,3,4,5],
      'gradingMode': 'average',
      'feedbackCategories': [
        {id:0, name:'Hyvää'},
        {id:1, name:'Kehitettävää'},
        {id:2, name:'Muuta'}
      ],
      'finalComment': 'Loppukaneetti\n<b>Toinen rivi</b>'
    }"

  #teardown: ->
  #  ok( true, "and one extra assert after each test" )
  

test "test with setup and teardown", ->
  expect(2)


test "loads fixtures", ->
  #ok(document.getElementById("fixture_view").tagName === "DIV", "is in the dom");
  #ok(this.fixtures[0] === fixture.el, "has return values for the el");
  #ok(this.fixtures[1].title === fixture.json[0].title, "has return values for json");
