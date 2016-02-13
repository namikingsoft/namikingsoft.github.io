gulp = require('gulp')
shell = require('gulp-shell')
config = require('../config').deploy

message = 'Site updated at ' + new Date().toLocaleString()

gulp.task 'deploy', shell.task [
  "git add --all"
  "git commit --allow-empty -m '#{message}'"
  "git push origin master"
],
  cwd: 'public'

gulp.task 'deploy:init', shell.task [
  "git init"
  "git remote add origin #{config.git.url}"
],
  cwd: 'public'

gulp.task 'deploy:clone', shell.task [
  "rm -rf public"
  "git clone --depth 1 -b master #{config.git.url} public"
]
