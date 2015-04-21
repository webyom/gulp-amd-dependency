fs = require 'fs'
path = require 'path'
async = require 'async'
gutil = require 'gulp-util'
through = require 'through2'

getInlineTemplate = (content, templateName) ->
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
	through.obj (file, enc, next) ->
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'File can\'t be null') if file.isNull()
		return @emit 'error', new gutil.PluginError('gulp-amd-dependency', 'Streams not supported') if file.isStream()
		if opt.excludeDependent
			got[file.path] = 1
		deps = []
		content = file.contents.toString()
		depArr = content.match /(?:^|[^.])\bdefine(?:\s*\(?|\s+)[^\[\{]*(\[[^\[\]]*\])/m
		depArr = depArr && depArr[1]
		depArr && depArr.replace /(["'])(\.[^"']+?)\1/mg, (full, quote, dep) ->
			dep = path.resolve path.dirname(file.path), dep
			got[dep] || deps.push dep
			got[dep] = 1
		content.replace /(?:^|[^.])\brequire\s*\(\s*(["'])(\.[^"']+?)\1\s*\)/g, (full, quote, dep) ->
			dep = path.resolve path.dirname(file.path), dep
			got[dep] || deps.push dep
			got[dep] = 1
		if path.extname(file.path) is '.coffee'
			content.replace /(?:^|[^.])\brequire\s+(["'])(\.[^"'#]+?)\1\s*(?:\r|\n)/g, (full, quote, dep) ->
				dep = path.resolve path.dirname(file.path), dep
				got[dep] || deps.push dep
				got[dep] = 1
		async.eachSeries(
			deps
			(filePath, cb) =>
				if fs.existsSync filePath
					filePath = filePath
				else if fs.existsSync filePath + '.coffee'
					filePath = filePath + '.coffee'
				else if fs.existsSync filePath + '.js'
					filePath = filePath + '.js'
				else
					filePath = filePath
					templateName = path.relative path.dirname(file.path), filePath
					newFileContent = getInlineTemplate content, templateName
				newFileContent ?= fs.readFileSync filePath
				newFile = new gutil.File
					base: file.base
					cwd: file.cwd
					path: filePath
					contents: newFileContent
				@push newFile
				if filePath isnt file.path
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
			(err) =>
				return @emit 'error', new gutil.PluginError('gulp-amd-dependency', err) if err
				next()
		)
