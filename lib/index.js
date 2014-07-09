(function() {
  var dependency, fs, gutil, path, through;

  fs = require('fs');

  path = require('path');

  gutil = require('gulp-util');

  through = require('through2');

  dependency = function(opt) {
    var got, scanned;
    if (opt == null) {
      opt = {};
    }
    got = {};
    scanned = {};
    return through.obj(function(file, enc, next) {
      var content, currentStream, depArr, deps;
      if (file.isNull()) {
        return this.emit('error', new gutil.PluginError('gulp-amd-dependency', 'File can\'t be null'));
      }
      if (file.isStream()) {
        return this.emit('error', new gutil.PluginError('gulp-amd-dependency', 'Streams not supported'));
      }
      if (scanned[file.path]) {
        return next();
      }
      scanned[file.path] = 1;
      currentStream = this;
      deps = [];
      content = file.contents.toString('utf-8');
      depArr = content.match(/(?:^|[^.]+?)\bdefine\s*\([^\[\{]*(\[[^\[\]]*\])/m);
      depArr = depArr && depArr[1];
      depArr && depArr.replace(/(["'])(\.[^"']+?)\1/mg, function(full, quote, dep) {
        dep = path.resolve(path.dirname(file.path), dep);
        got[dep] || deps.push(dep);
        return got[dep] = 1;
      });
      content.replace(/(?:^|[^.]+?)\brequire\s*\(\s*(["'])(\.[^"']+?)\1\s*\)/mg, function(full, quote, dep) {
        dep = path.resolve(path.dirname(file.path), dep);
        got[dep] || deps.push(dep);
        return got[dep] = 1;
      });
      deps.forEach(function(filePath) {
        var newFile;
        if (!/\.tpl\.html?$/.test(filePath)) {
          filePath = filePath + '.js';
        }
        if (fs.existsSync(filePath)) {
          newFile = new gutil.File({
            base: file.base,
            cwd: file.cwd,
            path: filePath,
            contents: fs.readFileSync(filePath)
          });
          currentStream.push(newFile);
          if (!scanned[filePath]) {
            return currentStream.write(newFile);
          }
        }
      });
      return next();
    });
  };

  module.exports = dependency;

}).call(this);
