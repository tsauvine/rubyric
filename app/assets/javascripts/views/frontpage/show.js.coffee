#= require bootstrap-3.1.1.min
#= require price-calculator

jQuery ->
  $('#carousel').carousel(interval: 15000)
  new PriceCalculator()
