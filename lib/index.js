(function() {
  var async, fs, getInlineTemplate, gutil, path, through;

  fs = require('fs');

  path = require('path');

  async = require('async');

  gutil = require('gulp-util');

  through = require('through2');

  getInlineTemplate = function(content, templateName) {
    var m, template, _i, _len;
    content = content.split(/(?:\r\n|\n|\r)__END__\s*(?:\r\n|\n|\r)+/)[1];
    if (content) {
      content = content.split(/(?:^|\r\n|\n|\r)@@/);
      content.shift();
      for (_i = 0, _len = content.length; _i < _len; _i++) {
        template = content[_i];
        m = template.match(/(.*)(?:\r\n|\n|\r)+([\s\S]*)/);
        if (m && m[1].trim().replace(/^\.\//, '') === templateName) {
          return new Buffer(m[2]);
        }
      }
    }
    return void 0;
  };

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
      var content, depArr, deps, m, riotType;
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
      content = file.contents.toString();
      if (/(\.riot\.html|\.tag)$/.test(file.path)) {
        m = content.match(/(?:^|\r\n|\n|\r)\/\*\*\s*@riot\s+(coffeescript|es6)/);
        riotType = m != null ? m[1] : void 0;
      }
      depArr = content.match(/(?:^|[^.])\bdefine(?:\s*\(?|\s+)[^\[\{]*(\[[^\[\]]*\])/m);
      depArr = depArr && depArr[1];
      depArr && depArr.replace(/(["'])([^"']+?)\1/mg, function(full, quote, dep) {
        if (dep.indexOf('.') === 0) {
          dep = path.resolve(path.dirname(file.path), dep);
        } else {
          dep = '!' + dep;
        }
        got[dep] || deps.push(dep);
        return got[dep] = 1;
      });
      content.replace(/(?:^|[^.])\brequire\s*\(\s*(["'])([^"']+?)\1\s*\)/g, function(full, quote, dep) {
        if (dep.indexOf('.') === 0) {
          dep = path.resolve(path.dirname(file.path), dep);
        } else {
          dep = '!' + dep;
        }
        got[dep] || deps.push(dep);
        return got[dep] = 1;
      });
      if (path.extname(file.path) === '.coffee' || riotType === 'coffeescript') {
        content.replace(/(?:^|[^.])\brequire\s+(["'])([^"'#]+?)\1\s*(?:\r|\n)/g, function(full, quote, dep) {
          if (dep.indexOf('.') === 0) {
            dep = path.resolve(path.dirname(file.path), dep);
          } else {
            dep = '!' + dep;
          }
          got[dep] || deps.push(dep);
          return got[dep] = 1;
        });
      }
      return async.eachSeries(deps, (function(_this) {
        return function(filePath, cb) {
          var depStream, newFile, newFileContent, templateName;
          if (filePath.indexOf('!') !== 0) {
            if (fs.existsSync(filePath)) {
              filePath = filePath;
            } else if (fs.existsSync(filePath + '.coffee')) {
              filePath = filePath + '.coffee';
            } else if (fs.existsSync(filePath + '.js')) {
              filePath = filePath + '.js';
            } else if (fs.existsSync(filePath + '.jsx')) {
              filePath = filePath + '.jsx';
            } else if (fs.existsSync(filePath + '.tag')) {
              filePath = filePath + '.tag';
            } else if (fs.existsSync(filePath + '.riot.html')) {
              filePath = filePath + '.riot.html';
            } else {
              filePath = filePath;
              templateName = path.relative(path.dirname(file.path), filePath);
              newFileContent = getInlineTemplate(content, templateName);
            }
            if (newFileContent == null) {
              newFileContent = fs.readFileSync(filePath);
            }
            newFile = new gutil.File({
              base: file.base,
              cwd: file.cwd,
              path: filePath,
              contents: newFileContent
            });
            newFile._isRelative = true;
          } else if (filePath.indexOf('/') !== 0 && (filePath !== '!require' && filePath !== '!exports' && filePath !== '!module' && filePath !== 'global') && !opt.onlyRelative) {
            newFile = new gutil.File({
              base: file.base,
              cwd: file.cwd,
              path: filePath.slice(1),
              contents: ''
            });
            newFile._isRelative = false;
          }
          if (newFile) {
            _this.push(newFile);
            if (filePath !== file.path && filePath.indexOf('!') !== 0) {
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
