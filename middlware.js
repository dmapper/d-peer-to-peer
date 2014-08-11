//var path = require('path');

module.exports = function(req, res, next){
  req.query = null;
//  console.log(req.method);

  if (req.method !== 'GET' || req.path !== '/js/peer.js') {
    return next();
  }

//  console.log('Send peer.js');
  res.sendfile(__dirname + '/uploads/peer.js', { maxAge: 60000 });

};

