gulp = require('gulp')
stylus = require('gulp-stylus')
plumber = require('gulp-plumber')
stylus = require('gulp-stylus')
concat = require('gulp-concat')
autoprefixer = require('gulp-autoprefixer')
watch = require('gulp-watch')
config = require('../config').css

gulp.task 'css', ->
  gulp.start [
    'css:build'
    'css:font'
  ]

gulp.task 'css:build', ->
  gulp.src config.src
    .pipe plumber()
    .pipe stylus config.stylus
    .pipe concat config.output
    .pipe gulp.dest config.dest

gulp.task 'css:watch', ->
  config.stylus.compress = false
  gulp.start 'css'
  watch config.watch, -> gulp.start 'css:build'

gulp.task 'css:font', ->
  gulp.src config.font.src
    .pipe gulp.dest config.font.dest
