module.exports =
  'babel-polyfill': 'dist/polyfill'
  'bootstrap': 'dist/js/bootstrap'
  'jsbarcode': 'dist/JsBarcode.all'
  'mobx': 'lib/mobx.umd'
  'mobx-state-tree': 'dist/mobx-state-tree.umd'
  'pdfmake': 'build/pdfmake'
  'prop-types': ->
    if process.env.NODE_ENV is 'production'
      'prop-types.min'
    else
      'prop-types'
  'react': ->
    if process.env.NODE_ENV is 'production'
      'umd/react.production.min'
    else
      'umd/react.development'
  'react-dom': ->
    if process.env.NODE_ENV is 'production'
      'umd/react-dom.production.min'
    else
      'umd/react-dom.development'
  'react-router': 'umd/ReactRouter'
  'socket.io-client': 'dist/socket.io'
  'xlsx': 'dist/xlsx.full.min'
