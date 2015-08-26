gulp = require('gulp')
del = require('del')

gulp.task 'build', ->
  gulp.start [
    'build:clean'
    'js'
    'css'
  ]

gulp.task 'build:clean', (callback) ->
  del ['public/*'], callback
