(function() {
  var async, fs, gutil, path, through;

  fs = require('fs');

  path = require('path');

  async = require('async');

  gutil = require('gulp-util');

  through = require('through2');

  module.exports = function(opt) {
    var got;
    if (opt == null) {
      opt = {};
    }
    if (opt._got == null) {
      opt._got = {};
    }
    got = opt._got;
    return through.obj(function(file, enc, next) {
      var content, depArr, deps;
      if (file.isNull()) {
        return this.emit('error', new gutil.PluginError('gulp-amd-dependency', 'File can\'t be null'));
      }
      if (file.isStream()) {
        return this.emit('error', new gutil.PluginError('gulp-amd-dependency', 'Streams not supported'));
      }
      if (opt.excludeDependent) {
        got[file.path] = 1;
      }
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
      return async.eachSeries(deps, (function(_this) {
        return function(filePath, cb) {
          var depStream, newFile;
          if (!/\.tpl\.html$/.test(filePath)) {
            if (fs.existsSync(filePath + '.coffee')) {
              filePath = filePath + '.coffee';
            } else {
              filePath = filePath + '.js';
            }
          }
          newFile = new gutil.File({
            base: file.base,
            cwd: file.cwd,
            path: filePath,
            contents: fs.readFileSync(filePath)
          });
          _this.push(newFile);
          if (filePath !== file.path) {
            depStream = module.exports(opt);
            depStream.pipe(through.obj(function(file, enc, next) {
              _this.push(file);
              return next();
            }, function() {
              return cb();
            }));
            return depStream.end(newFile);
          } else {
            return cb();
          }
        };
      })(this), (function(_this) {
        return function(err) {
          if (err) {
            return _this.emit('error', new gutil.PluginError('gulp-amd-dependency', err));
          }
          return next();
        };
      })(this));
    });
  };

}).call(this);
