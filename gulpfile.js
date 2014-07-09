var gulp = require('gulp');
var coffee = require('gulp-coffee');

gulp.task('compile', function (){
	return gulp.src('src/**/*.coffee')
		.pipe(coffee())
		.pipe(gulp.dest('lib'));
});

gulp.task('example', function (){
	var amdDependency = require('./lib/index');
	var through = require('through2');
	console.log('"example/src/index.js" depends on:');
	return gulp.src('example/src/index.js')
		.pipe(amdDependency())
		.pipe(through.obj(function(file, enc, cb) {
			console.log(file.path);
			cb();
		}));
});

gulp.task('default', ['compile']);