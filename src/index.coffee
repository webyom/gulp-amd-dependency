fs = require 'fs'
path = require 'path'
async = require 'async'
gutil = require 'gulp-util'
through = require 'through2'

EXTNAMES = ['.js', '.es6', '.coffee', '.jsx', '.tag', '.riot.html']

_isRelative = (dep) ->
	dep.indexOf('.') is 0

_getInlineTemplate = (content, templateName) ->
	content = content.split(/(?:\r\n|\n|\r)__END__\s*(?:\r\n|\n|\r)+/)[1]
	if content
		content = content.split(/(?:^|\r\n|\n|\r)@@/)
		content.shift()
		for template in content
			m = template.match /(.*)(?:\r\n|\n|\r)+([\s\S]*)/
			if m and m[1].trim().replace(/^\.\//, '') is templateName
				return new Buffer m[2]
	undefined

module.exports = (opt = {}) ->
	opt._got ?= {}
	got = opt._got
	isRelative = (dep, reqFilePath) ->
		res = _isRelative(dep)
		if opt.isRelative
			res = opt.isRelative dep, res, reqFilePath
		res
	through.obj (file, enc, next) ->
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'File can\'t be null') if file.isNull()
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'Streams not supported') if file.isStream()
		if opt.excludeDependent
			got[file.path] = 1
		deps = []
		content = file.contents.toString()
		if (/(\.riot\.html|\.tag)$/).test file.path
			m = content.match /(?:^|\r\n|\n|\r)\/\*\*\s*@riot\s+(coffeescript|es6)/
			riotType = m?[1]
		depArr = content.match /(?:^|[^.])\bdefine(?:\s*\(?|\s+)[^\[\{]*(\[[^\[\]]*\])/m
		depArr = depArr && depArr[1]
		depArr && depArr.replace /(["'])([^"']+?)\1/mg, (full, quote, dep) ->
			if isRelative dep, file.path
				dep = path.resolve path.dirname(file.path), dep
			else
				dep = '!' + dep
			got[dep] || deps.push dep
			got[dep] = 1
		content.replace /(?:^|[^.])\brequire\s*\(\s*(["'])([^"']+?)\1\s*\)/g, (full, quote, dep) ->
			if isRelative dep, file.path
				dep = path.resolve path.dirname(file.path), dep
			else
				dep = '!' + dep
			got[dep] || deps.push dep
			got[dep] = 1
		if path.extname(file.path) is '.coffee' or riotType is 'coffeescript'
			content.replace /(?:^|[^.])\brequire\s+(["'])([^"'#]+?)\1\s*(?:\r|\n)/g, (full, quote, dep) ->
				if isRelative dep, file.path
					dep = path.resolve path.dirname(file.path), dep
				else
					dep = '!' + dep
				got[dep] || deps.push dep
				got[dep] = 1
		async.eachSeries(
			deps
			(filePath, cb) =>
				if filePath.indexOf('!') isnt 0
					if not fs.existsSync(filePath) or fs.statSync(filePath).isDirectory()
						extnames =  (opt.extnames || EXTNAMES).concat()
						found = false
						while not found and extname = extnames.shift()
							if fs.existsSync filePath + extname
								filePath = filePath + extname
								found = true
						if not found
							templateName = path.relative path.dirname(file.path), filePath
							newFileContent = _getInlineTemplate content, templateName
					newFileContent ?= fs.readFileSync filePath
					newFile = new gutil.File
						base: file.base
						cwd: file.cwd
						path: filePath
						contents: newFileContent
					newFile._isRelative = true
				else if not opt.onlyRelative and filePath.indexOf('/') isnt 0 and filePath not in ['!require', '!exports', '!module', '!global']
					newFile = new gutil.File
						base: file.base
						cwd: file.cwd
						path: filePath.slice 1
						contents: ''
					newFile._isRelative = false
				if newFile
					@push newFile
					if filePath isnt file.path and filePath.indexOf('!') isnt 0
						depStream = module.exports opt
						depStream.pipe through.obj(
							(file, enc, next) =>
								@push file
								next()
							->
								cb()
						)
						depStream.end newFile
					else 
						cb()
				else
					cb()
			(err) =>
				return @emit 'error', new gutil.PluginError('gulp-amd-dependency', err) if err
				next()
		)
