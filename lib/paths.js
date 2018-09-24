(function() {
  module.exports = {
    'babel-polyfill': 'dist/polyfill',
    'bootstrap': 'dist/js/bootstrap',
    'jsbarcode': 'dist/JsBarcode.all',
    'mobx': 'lib/mobx.umd',
    'mobx-state-tree': 'dist/mobx-state-tree.umd',
    'pdfmake': 'build/pdfmake',
    'prop-types': function() {
      if (process.env.NODE_ENV === 'production') {
        return 'prop-types.min';
      } else {
        return 'prop-types';
      }
    },
    'react': function() {
      if (process.env.NODE_ENV === 'production') {
        return 'umd/react.production.min';
      } else {
        return 'umd/react.development';
      }
    },
    'react-dom': function() {
      if (process.env.NODE_ENV === 'production') {
        return 'umd/react-dom.production.min';
      } else {
        return 'umd/react-dom.development';
      }
    },
    'react-router': 'umd/ReactRouter',
    'socket.io-client': 'dist/socket.io',
    'xlsx': 'dist/xlsx.full.min'
  };

}).call(this);
