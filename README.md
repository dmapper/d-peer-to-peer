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


# license

MIT
