crypto = require 'crypto'
_ = require 'lodash'

fetchVendorScript = (scriptPath, cb) ->
  return cb() if global.Peer?

  #  console.log 'FETCH peerjs'
  $.getScript scriptPath, cb


module.exports = class MultiPeer
  view: __dirname + '/multi-peer'
  name: 'multi-peer'

  init: ->
    @context = @model.get 'context'

    @myId     = @model.get('myId')
    @myPeerId = @getPeerId [@myId, @context]

    @model.set 'myPeerId', @myPeerId
    @model.set 'state', 'off'
    @clients = {}

    console.log 'MultiPeer init: ', @model.get('clientIds'), @model.get('myId'), @model.get('context')

  create: ->
    # Make aspect ration 16/9
    unless @model.get 'dontChangeRatio'
      @remoteVideo.addEventListener "loadedmetadata", (event) =>
        actualRatio = @remoteVideo.videoWidth/@remoteVideo.videoHeight
        targetRatio = $(@remoteVideo).width()/$(@remoteVideo).height()
        adjustmentRatio = targetRatio/actualRatio
        $(@remoteVideo).css("-webkit-transform","scaleX(#{adjustmentRatio})")
        $(@remoteVideo).css("-moz-transform","scaleX(#{adjustmentRatio})")
        $(@remoteVideo).css("-ms-transform","scaleX(#{adjustmentRatio})")
        $(@remoteVideo).css("-o-transform","scaleX(#{adjustmentRatio})")
        $(@remoteVideo).css("transform","scaleX(#{adjustmentRatio})")

    fetchVendorScript '/js/peer.js', =>
      @createPeer()

  destroy: ->
    @peerDestroyed = true
    @model.set 'state', 'off'
    @localStream?.stop()
    @localStream = null

    @peer?.destroy()

    for clientId, client of @clients
      client?.call?.close()
      client?.stream?.stop()

      client?.call = null
      client?.stream = null

    console.log 'destroy!'

#  start: ->
#    @createVideoConnection()

#  stop: ->
#    if @peer and @videoCall
#      @videoCall?.close()
#
#    @localStream.stop() if @localStream?
#    @remoteStream.stop() if @remoteStream?
#    @emit('stop')

  createPeer: ->

#    {Peer} = require 'PeerJs'

    @peer = new Peer @myPeerId,
      host: global.env.PEERJS_HOST
      secure: global.env.PEERJS_SECURE
      port: 9000
      #key: 'lwjd5qra8257b9',
      debug: 3 # 3 - for deep debug
      config:
        'iceServers': global.env.ICE_SERVERS

#     Pass in optional STUN and TURN server for maximum network compatibility

    @registerPeerHandlers()

  registerPeerHandlers: ->

    @peer.on 'open',          @peerOnOpen.bind(this)
    @peer.on 'connection',    @peerOnConnection.bind(this)
    @peer.on 'call',          @peerOnCall.bind(this)
    @peer.on 'close',         @peerOnClose.bind(this)
    @peer.on 'disconnected',  @peerOnDisconnected.bind(this)
    @peer.on 'error',         @peerOnError.bind(this)

  createVideoConnection: ->

    return if @peer.disconnected

    @getVideoStream (err, stream) =>
      if err?
        console.log 'Error getting stream'
        return

      @localStream = stream

      video = @localVideo
      video.src = window.URL.createObjectURL stream

      @peer.listAllPeers (remotePeerIds) =>
#        console.log 'remotePeerIds', remotePeerIds

        clientIds = @model.get 'clientIds'

        clientIds.forEach (clientId) =>
          clientPeerId = @getPeerId [clientId, @context]

          if (clientPeerId in remotePeerIds) and clientId != @myId
#            console.log 'Call:', clientId, clientPeerId
            @clients[clientId] = @clients[clientId] || {}

            @clients[clientId].call = @peer.call clientPeerId, stream,
              metadata:
                clientId: @myId

            @registerCallHandlers(@clients[clientId].call, clientId)




  registerCallHandlers: (videoCall, clientId) =>

    videoCall.on 'stream', (stream) =>
#      console.log('clientId', clientId  )

      $video = $('#' + clientId)
#      console.log('$video', $video);

      $video.prop('src', window.URL.createObjectURL(stream));

      if not @model.get('activeClient')
        @remoteVideo.src = window.URL.createObjectURL(stream)
        @model.set 'activeClient', clientId

      @clients[clientId].stream = stream


    videoCall.on 'close', () =>
      if videoCall?
        clientId = videoCall.metadata.clientId
        @clients[clientId]?.stream?.stop()
        @clients[clientId]?.stream = null
        @clients[clientId]?.call = null

        if @model.get('activeClient') is clientId
          #TODO Add autoselect existing client
          @remoteVideo.src = ''
          @model.set 'activeClient', undefined

    videoCall.on 'error', (err) =>
#      console.log 'peerjs: call error:', err.type

  getVideoStream: (cb) ->
    navigator.getUserMedia =  navigator.getUserMedia || \
                              navigator.webkitGetUserMedia || \
                              navigator.mozGetUserMedia || \
                              navigator.msGetUserMedia
    if navigator.getUserMedia
      navigator.getUserMedia
        video: true
        audio: true
      , (stream) =>
        cb null, stream
      , cb
    else
      cb('Browser can not give audio/video stream')


  # ----------------------------- VIDEO CONNECTION HANDLERS --------------------------------
#  callOnError: (err) =>
#    console.log 'peerjs: call error:', err.type
#
#  callOnStream: (stream) =>
#    @model.set 'videoState', 'on'
#    console.log 'peerjs: call stream:'
#
#    video = @remoteVideo
#    video.src = window.URL.createObjectURL stream
#
#  callOnClose: =>
#    @model.set 'videoState', 'off'
#    console.log 'peerjs: call close:'
#
#    if @stream?
#      @stream.close()


  # ----------------------------- PEER CONNECTION HANDLERS ---------------------------------

  #When peer is created
  peerOnOpen: (id) ->
#    console.log 'Id of peer: ' + @peer.id
    @model.set 'state', 'on'
    @createVideoConnection()
#    console.log 'peerjs: peer: open: ', id

  peerOnConnection: (data) ->
#    console.log 'peerjs: peer: connection'

  peerOnCall: (videoCall) ->
    {clientId} = videoCall.metadata

    @clients[clientId] = @clients[clientId] || {}

    @clients[clientId]?.call?.close()

    @clients[clientId].call = videoCall
    @registerCallHandlers(videoCall, clientId)

#    @getVideoStream (err, stream) =>
#      if err
#        console.log 'Error getting stream'
#        return
#
#      video = @localVideo
#      video.src = window.URL.createObjectURL stream

    @clients[clientId].call.answer @localStream
#      @localStream = stream

#    console.log 'peerjs: peer: call'
  peerOnClose: ->
#    console.log 'peerjs: peer: close'
    @model.set 'state', 'off'

  _reconnect: _.debounce ->
#    console.log 'peerjs: peer: try to reconnect'
    # Hack reconnection because it loses id of partner somehow
    @peer._lastServerId = @myPeerId
    @peer.id = @myPeerId
    unless @peerDestroyed
      @peer.reconnect()
  , 5000

  peerOnDisconnected: ->
#    console.log 'peerjs: peer: disconnected'
#    console.log 'Waiting 5 sec to reconnect'
    @model.set 'state', 'off'
    unless @peerDestroyed
      @_reconnect.call(this)

  peerOnError: (err) ->
#    console.log 'peerjs: peer: error:', err.type, err

    switch err.type
      when 'peer-unavailable'
        @localStream?.stop()
        @localStream = null

  changeFeed: (clientId) =>
    stream = @clients[clientId]?.stream;
    if stream
      @remoteVideo.src = window.URL.createObjectURL stream
      @model.set 'activeClient', clientId


  getPeerId: (context) ->
    return context if typeof context is 'string'
    h = crypto.createHash('md5').update(context.sort().join('')).digest('hex')
    h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20)
