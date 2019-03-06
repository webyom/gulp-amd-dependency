_ = require 'lodash'
fs = require 'fs'
path = require 'path'
glob = require 'glob'
async = require 'async'
Vinyl = require 'vinyl'
PluginError = require 'plugin-error'
through = require 'through2'
amdPathsCollection = require require.resolve('amd-paths-collection',
		paths: [path.resolve('node_modules')].concat require.resolve.paths 'amd-paths-collection'
	)

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
	collection = amdPathsCollection(opt.collectionOpt)
	async.each(
		Object.keys(pkg.dependencies || []) 
		(dep, cb) ->
			return cb() if opt.ignore && opt.ignore.indexOf(dep) >= 0
			depDir = path.resolve 'node_modules', dep
			if fs.statSync(depDir).isDirectory()
				depPkg = require path.resolve(depDir, 'package.json')

				pushStream = (dep, depFile, newFile) ->
					version = opt.withVersion && depPkg.version || ''
					if not newFile
						contents = fs.readFileSync(depFile).toString()
						sourceMap = contents.match /\/\/\s*#\s*sourceMappingURL=(.+)/
						depFileDir = path.dirname depFile
						sourceMapPath = sourceMap && path.resolve(depFileDir, sourceMap[1].trim())
						sourceMapFile = null
						if sourceMapPath and fs.existsSync(sourceMapPath) and (!opt.flatten or depFileDir is path.dirname(sourceMapPath))
							sourceMapFile = new Vinyl
								base: path.resolve 'node_modules'
								cwd: cwd
								path: sourceMapPath
								contents: fs.readFileSync sourceMapPath
						newFile = new Vinyl
							base: path.resolve 'node_modules'
							cwd: cwd
							path: depFile
							contents: new Buffer contents
					originalPathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
					if opt.flatten
						newFile.path = path.join depDir, version, path.basename(depFile)
						if sourceMapFile
							sourceMapFile.path = path.join depDir, version, path.basename(sourceMapFile.path)
						pathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
					else
						if version
							newFile.path = path.join depDir, version, path.relative(depDir, newFile.path)
							pathMap[dep] = path.join (opt.base || ''), path.relative(newFile.base, newFile.path).replace(/\.js$/i, '')
						else
							pathMap[dep] = originalPathMap[dep]
					stream.push newFile
					stream.push sourceMapFile if sourceMapFile

				depFile = ''
				converted = opt.paths && opt.paths[dep] || collection[dep]

				if converted
					if typeof converted is 'function'
						converted = converted (err, file) ->
							return cb(err) if err
							if typeof file is 'string'
								depFile = path.resolve depDir, file + '.js'
								pushStream dep, depFile
							else if file
								depFile = file.path
								pushStream dep, depFile, file
							cb()
						return if typeof converted not in ['object', 'string']
					if converted and typeof converted is 'object'
						return async.each(
							Object.keys(converted).filter((item) -> item is dep or not collection[item] and (item.indexOf(dep + '/') is 0 or item.indexOf(dep + '-') is 0 or item.indexOf(dep + '_') is 0))
							(dep, cb) ->
								return cb() if opt.ignore && opt.ignore.indexOf(dep) >= 0
								if typeof converted[dep] is 'function'
									converted[dep] (err, file) ->
										return cb(err) if err
										if typeof file is 'string'
											depFile = path.resolve depDir, file + '.js'
											pushStream dep, depFile
										else
											depFile = file.path
											pushStream dep, depFile, file
										cb()
								else
									depFile = path.resolve depDir, converted[dep] + '.js'
									pushStream dep, depFile
									cb()
							(err) ->
								cb err
						)
					else if typeof converted is 'string'
						depFile = path.resolve depDir, converted + '.js'
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
					pushStream dep, depFile
			cb()
		(err) ->
			return stream.emit 'error', new PluginError('gulp-amd-dependency', err) if err
			newFile = new Vinyl
				base: cwd
				cwd: cwd
				path: path.join cwd, 'package-dependencies-paths.js'
				contents: new Buffer 'var __package_dependencies_paths = ' + JSON.stringify(pathMap, null, 2) + ';\n' + (if opt.flatten then '/*' + JSON.stringify(originalPathMap, null, 2) + '*/\n' else '')
			stream.end newFile
	)
	stream
