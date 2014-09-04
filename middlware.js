//var path = require('path');

module.exports = function(req, res, next){
//  req.query = null;

  if (req.method !== 'GET' || req.path !== '/js/peer.js') {
    return next();
  }

  res.sendfile(__dirname + '/uploads/peer.js', { maxAge: 60000 });

};

