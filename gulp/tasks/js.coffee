gulp = require('gulp')
gulpif = require('gulp-if')
gutil = require('gulp-util')
uglify = require('gulp-uglify')
browserify = require('browserify')
watchify = require('watchify')
sourcemaps = require('gulp-sourcemaps')
source = require('vinyl-source-stream')
buffer = require('vinyl-buffer')
assign = require('lodash').assign
config = require('../config').js

bundle = ->
  bundler.bundle()
    .on 'error', gutil.log.bind(gutil, 'Browserify Error')
    .pipe source config.output
    .pipe buffer()
    .pipe sourcemaps.init config.sourcemaps
    .pipe gulpif config.minify, uglify config.uglify
    .pipe sourcemaps.write './'
    .pipe gulp.dest config.dest

opts = assign {}, watchify.args, config.browserify
bundler = browserify opts
bundler.on 'log', gutil.log

gulp.task 'js', ->
  gulp.start [
    'js:build'
  ]

gulp.task 'js:build', bundle

gulp.task 'js:watch', ->
  bundler = watchify bundler
  bundler.on 'update', bundle
  config.minify = false
  gulp.start 'js:build'
