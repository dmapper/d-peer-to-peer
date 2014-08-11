# d-peer-to-peer

Derby peerjs video-component

# install

With [npm](https://npmjs.org) do:

```
npm install d-peer-to-peer
```

Require the module:

```
peer = requre 'd-peer-to-peer'
```

Start server, get middleware

```
middleware = peer()
```

Add the middleware to expressjs (it always should be FIRST middleware)

```
expressApp.
  use middleware
```

Add component in derby-app

```
app.component require('d-peer-to-peer/single-peer/single-peer')

```

Use it in the view-files: f.e:
```
  view(name="single-peer",
      context="{{#root._page.player.teamId}}",
      myId="{{#root._page.player.id}}",
      partnerId="{{#root._page.player.partnerId}}",
      on-play="chat.scrollDown()")
```

# license

MIT
