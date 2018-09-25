_ = require 'lodash'
fs = require 'fs'
path = require 'path'
glob = require 'glob'
async = require 'async'
Vinyl = require 'vinyl'
PluginError = require 'plugin-error'
through = require 'through2'
amdPathsCollection = require 'amd-paths-collection'

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
	setGot = (p) ->
		got[p] = 1
		extnames = (opt.extnames || EXTNAMES).concat()
		for extname in extnames
			got[p + extname] = 1
	through.obj (file, enc, next) ->
		return @emit 'error', new PluginError('gulp-amd-dependency', 'File can\'t be null') if file.isNull()
		return @emit 'error', new PluginError('gulp-amd-dependency', 'Streams not supported') if file.isStream()
		dirname = path.dirname(file.path)
		if opt.excludeDependent
			setGot file.path
		deps = []
		content = file.contents.toString()
		if (/(\.riot\.html|\.tag)$/).test file.path
			m = content.match /(?:^|\r\n|\n|\r)\/\*\*\s*@riot\s+(coffeescript|es6)/
			riotType = m?[1]
		depArr = content.match /(?:^|[^.])\bdefine(?:\s*\(\s*|\s+)(?:(["'])[^"']+?\1\s*,\s*)*(\[[^\[\]]*\])/m
		depArr = depArr && depArr[2]
		depArr && depArr.replace /(["'])([^"']+?)\1/mg, (full, quote, dep) ->
			if isRelative dep, file.path
				dep = path.resolve dirname, dep
			else
				dep = '!' + dep
			got[dep] || deps.push dep
			setGot dep
		handleRequire = (full, quote, dep) ->
			if isRelative dep, file.path
				if dep.indexOf('*') is -1
					dep = path.resolve dirname, dep
				else if not got[dep]
					tmp = glob.sync dep, cwd: dirname
					for p in tmp
						p = path.resolve dirname, p
						if not fs.statSync(p).isDirectory()
							got[p] || deps.push p
							extnames = (opt.extnames || EXTNAMES).concat()
							for extname in extnames
								if _.endsWith p, extname
									setGot p.slice 0, -extname.length
							setGot p
			else
				dep = '!' + dep
			if not got[dep] and dep.indexOf('*') is -1
				deps.push dep
			setGot dep
		content.replace /(?:^|[^.])\brequire\s*\(\s*(["'])([^"']+?)\1\s*\)/g, handleRequire
		if path.extname(file.path) is '.coffee' or riotType is 'coffeescript'
			content.replace /(?:^|[^.])\brequire\s+(["'])([^"'#]+?)\1\s*(?:\r|\n)/g, handleRequire
		async.eachSeries(
			deps
			(filePath, cb) =>
				if filePath.indexOf('!') isnt 0
					if not fs.existsSync(filePath) or fs.statSync(filePath).isDirectory()
						extnames = (opt.extnames || EXTNAMES).concat()
						found = false
						while not found and extname = extnames.shift()
							if fs.existsSync filePath + extname
								filePath = filePath + extname
								found = true
						if not found
							templateName = path.relative dirname, filePath
							newFileContent = _getInlineTemplate content, templateName
					newFileContent ?= fs.readFileSync filePath
					newFile = new Vinyl
						base: file.base
						cwd: file.cwd
						path: filePath
						contents: newFileContent
					newFile._isRelative = true
				else if not opt.onlyRelative and filePath.indexOf('/') isnt 0 and filePath not in ['!require', '!exports', '!module', '!global']
					newFile = new Vinyl
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
				return @emit 'error', new PluginError('gulp-amd-dependency', err) if err
				next()
		)

module.exports.findPackageDependencies = (opt = {}) ->
	stream = through.obj (file, enc, next) ->
		@push file
		next()
	originalPathMap = {}
	pathMap = {}
	cwd = process.cwd()
	pkg = require path.resolve 'package.json'
	Object.keys(pkg.dependencies || []).forEach (dep) ->
		return if opt.ignore && opt.ignore.indexOf(dep) >= 0
		depDir = path.resolve 'node_modules', dep
		if fs.statSync(depDir).isDirectory()
			depPkg = require path.resolve(depDir, 'package.json')
			depFile = ''
			if opt.paths && opt.paths[dep]
				if typeof opt.paths[dep] is 'function'
					depFile = path.resolve depDir, opt.paths[dep]()
				else
					depFile = path.resolve depDir, opt.paths[dep]
				depFile = depFile + '.js'
			else if amdPathsCollection[dep]
				if typeof amdPathsCollection[dep] is 'function'
					depFile = path.resolve depDir, amdPathsCollection[dep]()
				else
					depFile = path.resolve depDir, amdPathsCollection[dep]
				depFile = depFile + '.js'
			else if depPkg.browser and typeof depPkg.browser is 'string'
				depFile = path.resolve depDir, depPkg.browser
				if !fs.existsSync(depFile) && fs.existsSync(depFile + '.js')
					depFile = depFile + '.js'
			else if fs.existsSync path.resolve(depDir, 'dist', dep + '.js')
				depFile = path.resolve(depDir, 'dist', dep + '.js')
			else if depPkg.main and typeof depPkg.main is 'string'
				depFile = path.resolve depDir, depPkg.main
				if !fs.existsSync(depFile) && fs.existsSync(depFile + '.js')
					depFile = depFile + '.js'
			else if fs.existsSync path.resolve(depDir, dep + '.js')
				depFile = path.resolve(depDir, dep + '.js')
			else if fs.existsSync path.resolve(depDir, 'index.js')
				depFile = path.resolve(depDir, 'index.js')
			if depFile and path.extname(depFile) is '.js' 
				newFile = new Vinyl
					base: path.resolve 'node_modules'
					cwd: cwd
					path: depFile
					contents: fs.readFileSync depFile
				if opt.flatten
					originalPathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
					newFile.path = path.join depDir, path.basename(depFile)
					pathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
				else
					originalPathMap[dep] = pathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
				stream.push newFile
	newFile = new Vinyl
		base: cwd
		cwd: cwd
		path: path.join cwd, 'package-dependencies-paths.js'
		contents: new Buffer 'var __package_dependencies_paths = ' + JSON.stringify(pathMap, null, 2) + ';\n' + (if opt.flatten then '/*' + JSON.stringify(originalPathMap, null, 2) + '*/\n' else '')
	stream.end newFile
	stream
