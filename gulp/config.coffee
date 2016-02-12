nib = require 'nib'

path =
  src: './assets'
  dest: './static'
  bower: './bower_components'

js =
  browserify:
    entries: [path.src + '/js/index.coffee']
    transform: ['coffeeify', 'debowerify']
    extensions: ['.coffee', '.js']
  dest: path.dest + '/js/'
  output: 'bundle.js'
  sourcemaps:
    loadMaps: true
  uglify:
    preserveComments: 'some'
  minify: true

css =
  src: [
    path.bower + '/font-awesome/css/font-awesome.min.css'
    path.bower + '/bootstrap/dist/css/bootstrap.min.css'
    path.bower + '/highlightjs/styles/default.css'
    path.src + '/css/index.styl'
  ]
  dest: path.dest + '/css/'
  output: 'bundle.css'
  minify: true
  stylus:
    use: nib()
    compress: true
  autoprefixer:
    browsers: ['last 2 versions']
  watch: path.src + '/css/**'
  font:
    src: path.bower + '/font-awesome/fonts/fontawesome-webfont.*'
    dest: path.dest + '/fonts/'

deploy =
  git:
    url: 'git@github.com:namikingsoft/namikingsoft.github.io.git'

module.exports =
  path: path
  js: js
  css: css
  deploy: deploy
