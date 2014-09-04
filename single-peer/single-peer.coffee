crypto = require 'crypto'
_ = require 'lodash'

getContextId = (context) ->
  return context if typeof context is 'string'
  h = crypto.createHash('md5').update(context.sort().join('')).digest('hex')
  h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20)

fetchVendorScript = (scriptPath, cb) ->
  return cb() if global.Peer?

#  console.log 'FETCH peerjs'
  $.getScript scriptPath, cb

module.exports = class SinglePeer
  view: __dirname + '/single-peer'
  name: 'single-peer'

  init: ->
    @context = @model.get 'context'

#    console.log 'videocall init: ', @context, @model.get('myId'), @model.get('partnerId')

    if @context?
      @myPeerId   = getContextId [@model.get('myId'), @context]
      @partnerId  = getContextId [@model.get('partnerId'), @context]
    else
      @myPeerId   = @model.get 'myId'
      @partnerId  = @model.get 'partnerId'

#    console.log 'videocall init: ', @context, @myPeerId, @partnerId

    @model.set 'myPeerId', @myPeerId
    @model.set 'partnerPeerId', @partnerId

    @model.set 'state', 'off'
    @model.set 'videoState', 'off'

    @model.setNull 'isPartnerOnline', false

    @model.on 'change', 'videoState', (value, previous) =>
      unless value is previous
        switch value
          when 'on' then @emit 'play'
          when 'off' then @emit 'stop'

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

#    console.log 'create video component!'
    fetchVendorScript '/js/peer.js', =>
      @createPeer()

#    @createDataConnection()

  destroy: ->
    @peerDestroyed = true
    @model.set 'state', 'off'
    @localStream?.stop()
    @remoteStream?.stop()
    @localStream = null
    @remoteStream = null
    @peer.destroy()

    console.log 'destroy!'

  checkPartnerStatus: =>

    return unless @peer?
    return if @peerDestroyed

    unless @peer.disconnected
      @peer.listAllPeers (remotePeerIds) =>
        @model.setDiff 'isPartnerOnline', @partnerId in remotePeerIds
    else
      @model.setDiff 'isPartnerOnline', false


    setTimeout @checkPartnerStatus.bind(this), 500


  start: ->
    @createVideoConnection()

  stop: ->
    if @peer
      @videoCall?.close()
      @videoCall = null

    @localStream?.stop()
    @remoteStream?.stop()
    @localStream = null
    @remoteStream = null
#    @emit('stop')

  createPeer: ->
#    @peer = new Peer(@myId, key: 'lwjd5qra8257b9')
#     PeerJS object

#    {Peer} = require 'PeerJs'

    @peer = new Peer @myPeerId,
      host: global.env.PEERJS_HOST
      secure: global.env.PEERJS_SECURE
      port: 9000
      debug: 3 # 3 - for deep debug
      config:
        'iceServers': global.env.ICE_SERVERS

#     Pass in optional STUN and TURN server for maximum network compatibility

    @registerPeerHandlers()

  _createPeer: _.debounce =>
    @createPeer()
  , 5000

  registerPeerHandlers: ->

    @peer.on 'open',          @peerOnOpen.bind(this)
    @peer.on 'connection',    @peerOnConnection.bind(this)
    @peer.on 'call',          @peerOnCall.bind(this)
    @peer.on 'close',         @peerOnClose.bind(this)
    @peer.on 'disconnected',  @peerOnDisconnected.bind(this)
    @peer.on 'error',         @peerOnError.bind(this)

  createDataConnection: ->
    @data = @peer.connect @partnerId

  registerDataHandlers: ->
    @data.on 'error', @dataOnError.bind(this)
    @data.on 'data',  @dataOnData.bind(this)
    @data.on 'open',  @dataOnOpen.bind(this)
    @data.on 'close', @dataOnClose.bind(this)

  createVideoConnection: ->
#    console.log 'start video connection'
    @peer.listAllPeers (remotePeerIds) =>

      unless @partnerId in remotePeerIds
        console.log "Video-partner isn't accessible"
        return

      @getVideoStream (err, stream) =>
        if err?
          console.log 'Error getting stream'
          return

        video = @localVideo
        video.src = window.URL.createObjectURL stream

        @videoCall?.close()

        @videoCall = @peer.call @partnerId, stream
        @localStream = stream

        @registerCallHandlers()

  registerCallHandlers: =>
#    console.log 'registerCallHandlers', @videoCall

#    @videoCall.on 'stream', @callOnStream.bind(this)
#    @videoCall.on 'close', @callOnClose.bind(this)
#    @videoCall.on 'error', @callOnError.bind(this)

    @videoCall.on 'stream', (stream) =>
      @model.set 'videoState', 'on'
#      @emit('play')
#      console.log 'peerjs: call stream:'

      video = @remoteVideo
      video.src = window.URL.createObjectURL stream

      @remoteStream = stream


    @videoCall.on 'close', () =>
      @model.set 'videoState', 'off'
      @localStream?.stop()
      @remoteStream?.stop()
      @localStream = null
      @remoteStream = null
      @videoCall = null
#      console.log 'peerjs: call close:'

    @videoCall.on 'error', (err) =>
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

  # ----------------------------- DATA CONNECTION HANDLERS ---------------------------------



  dataOnError: (err) ->
#    console.log 'peerjs: data error:', err.type

  dataOnData: (data) ->
#    console.log 'peerjs: data data:'

  dataOnOpen: () ->
#    console.log 'peerjs: data open:'

  dataOnClose: () ->
#    console.log 'peerjs: data close:'

  # ----------------------------- PEER CONNECTION HANDLERS ---------------------------------

  #When peer is created
  peerOnOpen: (id) ->
#    console.log 'Id of peer: ' + @peer.id
    @model.set 'state', 'on'
    @checkPartnerStatus()
#    console.log 'peerjs: peer: open: ', id

  peerOnConnection: (data) ->
#    console.log 'peerjs: peer: connection'

  peerOnCall: (videoCall) ->
    @videoCall?.close()

    @videoCall = videoCall
    @registerCallHandlers()

    @getVideoStream (err, stream) =>
      if err
        console.log 'Error getting stream'
        return

      video = @localVideo
      video.src = window.URL.createObjectURL stream

      @videoCall.answer stream
      @localStream = stream

#    console.log 'peerjs: peer: call'
  peerOnClose: ->
#    console.log 'peerjs: peer: close'
    @model.set 'state', 'off'

  _reconnect: _.debounce ->
#    console.log 'peerjs: peer: try to reconnect'
    # Hack reconnection because it loses id of partner somehow
    if !@peer.destroyed and @peer.disconnected
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

  peerOnError: (err) =>
    console.log 'peerjs: peer: error:', err.type, err

    switch err.type
      when 'peer-unavailable'
        @localStream?.stop()
        @remoteStream?.stop()

        @localStream = null
        @remoteStream = null

        @videoCall?.close()
        @videoCall = null

    if @peer.destroyed
      console.log 'PeerJs: Peer is destroyed, recreating the peer'
      @_createPeer()