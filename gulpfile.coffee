gulp = require 'gulp'
coffee = require 'gulp-coffee'

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
				'async/support': 'support/sync-package-managers'
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
