fs = require 'fs'
path = require 'path'
gulp = require 'gulp'
coffee = require 'gulp-coffee'
Vinyl = require 'vinyl'

gulp.task 'compile', ->
	gulp.src('src/**/*.coffee')
		.pipe coffee()
		.pipe gulp.dest('lib')

gulp.task 'example', ->
	through = require 'through2'
	amdDependency = require './lib/index'

	amdDependency.findPackageDependencies({
		flatten: true
		base: 'package-dependencies'
		ignore: ['amd-paths-collection']
		paths:
			'async':
				'async': 'lib/async'
				'async/support-2': (cb) ->
					fs.readFile path.resolve('node_modules', 'async/support/sync-package-managers.js'), (err, content) ->
						return cb err if err
						cb null, new Vinyl
							base: path.resolve 'node_modules'
							cwd: process.cwd()
							path: path.resolve 'node_modules', 'async/support/sync-package-managers-2.js'
							contents: content
				'async/support': (cb) ->
					cb null, 'support/sync-package-managers'
	}).pipe gulp.dest 'example/package-dependencies'

	console.log '"example/src/index.js" depends on:'
	gulp.src('example/src/index.js')
		.pipe amdDependency
			isRelative: (id, isRelative) ->
				if id is './mod-a'
					false
				else
					isRelative
		.pipe through.obj (file, enc, cb) ->
			console.log file.path, file._isRelative
			cb()

gulp.task 'default', ['compile']
