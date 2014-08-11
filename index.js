var middlware = require('./middlware');

module.exports = function (opt) {

  opt = opt || {};

  var options = extend({
    port: 9000,
    allow_discovery: true
  }, opt);

  var PeerServer = require('peer').PeerServer;

  console.log('Start peer server: ', options);

  new PeerServer(options);

  return middlware;

};


function extend(dest, source) {
  source = source || {};
  for(var key in source) {
    if(source.hasOwnProperty(key)) {
      dest[key] = source[key];
    }
  }
  return dest;
}