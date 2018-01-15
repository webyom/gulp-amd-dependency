(function() {
  var EXTNAMES, PluginError, Vinyl, _, _getInlineTemplate, _isRelative, async, fs, glob, path, through;

  _ = require('lodash');

  fs = require('fs');

  path = require('path');

  glob = require('glob');

  async = require('async');

  Vinyl = require('vinyl');

  PluginError = require('plugin-error');

  through = require('through2');

  EXTNAMES = ['.js', '.es6', '.coffee', '.jsx', '.tag', '.riot.html'];

  _isRelative = function(dep) {
    return dep.indexOf('.') === 0;
  };

  _getInlineTemplate = function(content, templateName) {
    var i, len, m, template;
    content = content.split(/(?:\r\n|\n|\r)__END__\s*(?:\r\n|\n|\r)+/)[1];
    if (content) {
      content = content.split(/(?:^|\r\n|\n|\r)@@/);
      content.shift();
      for (i = 0, len = content.length; i < len; i++) {
        template = content[i];
        m = template.match(/(.*)(?:\r\n|\n|\r)+([\s\S]*)/);
        if (m && m[1].trim().replace(/^\.\//, '') === templateName) {
          return new Buffer(m[2]);
        }
      }
    }
    return void 0;
  };

  module.exports = function(opt) {
    var got, isRelative, setGot;
    if (opt == null) {
      opt = {};
    }
    if (opt._got == null) {
      opt._got = {};
    }
    got = opt._got;
    isRelative = function(dep, reqFilePath) {
      var res;
      res = _isRelative(dep);
      if (opt.isRelative) {
        res = opt.isRelative(dep, res, reqFilePath);
      }
      return res;
    };
    setGot = function(p) {
      var extname, extnames, i, len, results;
      got[p] = 1;
      extnames = (opt.extnames || EXTNAMES).concat();
      results = [];
      for (i = 0, len = extnames.length; i < len; i++) {
        extname = extnames[i];
        results.push(got[p + extname] = 1);
      }
      return results;
    };
    return through.obj(function(file, enc, next) {
      var content, depArr, deps, dirname, handleRequire, m, riotType;
      if (file.isNull()) {
        return this.emit('error', new PluginError('gulp-amd-dependency', 'File can\'t be null'));
      }
      if (file.isStream()) {
        return this.emit('error', new PluginError('gulp-amd-dependency', 'Streams not supported'));
      }
      dirname = path.dirname(file.path);
      if (opt.excludeDependent) {
        setGot(file.path);
      }
      deps = [];
      content = file.contents.toString();
      if (/(\.riot\.html|\.tag)$/.test(file.path)) {
        m = content.match(/(?:^|\r\n|\n|\r)\/\*\*\s*@riot\s+(coffeescript|es6)/);
        riotType = m != null ? m[1] : void 0;
      }
      depArr = content.match(/(?:^|[^.])\bdefine(?:\s*\(\s*|\s+)(?:(["'])[^"']+?\1\s*,\s*)*(\[[^\[\]]*\])/m);
      depArr = depArr && depArr[2];
      depArr && depArr.replace(/(["'])([^"']+?)\1/mg, function(full, quote, dep) {
        if (isRelative(dep, file.path)) {
          dep = path.resolve(dirname, dep);
        } else {
          dep = '!' + dep;
        }
        got[dep] || deps.push(dep);
        return setGot(dep);
      });
      handleRequire = function(full, quote, dep) {
        var extname, extnames, i, j, len, len1, p, tmp;
        if (isRelative(dep, file.path)) {
          if (dep.indexOf('*') === -1) {
            dep = path.resolve(dirname, dep);
          } else if (!got[dep]) {
            tmp = glob.sync(dep, {
              cwd: dirname
            });
            for (i = 0, len = tmp.length; i < len; i++) {
              p = tmp[i];
              p = path.resolve(dirname, p);
              if (!fs.statSync(p).isDirectory()) {
                got[p] || deps.push(p);
                extnames = (opt.extnames || EXTNAMES).concat();
                for (j = 0, len1 = extnames.length; j < len1; j++) {
                  extname = extnames[j];
                  if (_.endsWith(p, extname)) {
                    setGot(p.slice(0, -extname.length));
                  }
                }
                setGot(p);
              }
            }
          }
        } else {
          dep = '!' + dep;
        }
        if (!got[dep] && dep.indexOf('*') === -1) {
          deps.push(dep);
        }
        return setGot(dep);
      };
      content.replace(/(?:^|[^.])\brequire\s*\(\s*(["'])([^"']+?)\1\s*\)/g, handleRequire);
      if (path.extname(file.path) === '.coffee' || riotType === 'coffeescript') {
        content.replace(/(?:^|[^.])\brequire\s+(["'])([^"'#]+?)\1\s*(?:\r|\n)/g, handleRequire);
      }
      return async.eachSeries(deps, (function(_this) {
        return function(filePath, cb) {
          var depStream, extname, extnames, found, newFile, newFileContent, templateName;
          if (filePath.indexOf('!') !== 0) {
            if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
              extnames = (opt.extnames || EXTNAMES).concat();
              found = false;
              while (!found && (extname = extnames.shift())) {
                if (fs.existsSync(filePath + extname)) {
                  filePath = filePath + extname;
                  found = true;
                }
              }
              if (!found) {
                templateName = path.relative(dirname, filePath);
                newFileContent = _getInlineTemplate(content, templateName);
              }
            }
            if (newFileContent == null) {
              newFileContent = fs.readFileSync(filePath);
            }
            newFile = new Vinyl({
              base: file.base,
              cwd: file.cwd,
              path: filePath,
              contents: newFileContent
            });
            newFile._isRelative = true;
          } else if (!opt.onlyRelative && filePath.indexOf('/') !== 0 && (filePath !== '!require' && filePath !== '!exports' && filePath !== '!module' && filePath !== '!global')) {
            newFile = new Vinyl({
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
            return _this.emit('error', new PluginError('gulp-amd-dependency', err));
          }
          return next();
        };
      })(this));
    });
  };

}).call(this);
