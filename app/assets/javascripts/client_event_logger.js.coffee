class @ClientEventLogger
  @sendInterval = 10

  constructor: (@sessionId) ->
    @startTime = new Date().getTime()
    @url = '/client_event'
    @buffer = []  # Array of event hashes [{t: 5, m: json}, ...]
    @interval = undefined
  
  log: (message) ->
    timestamp = ((new Date().getTime() - @startTime) / 1000).toFixed(1)
    @buffer.push({t: timestamp, m: message})
    
    unless @interval
      @interval = setInterval((=> this.flush()), ClientEventLogger.sendInterval * 1000)
      this.flush()   # Send the first burst immediately

  flush: ->
    return if @buffer.length < 1
  
    $.ajax
      url: @url
      type: 'post'
      dataType: 'json'
      data: { session: @sessionId, events: JSON.stringify(@buffer) }

    @buffer = []
