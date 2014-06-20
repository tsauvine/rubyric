#= require bootstrap-3.1.1.min
#= require price-calculator

jQuery ->
  $('#carousel').carousel(interval: 10000)
  new PriceCalculator()
