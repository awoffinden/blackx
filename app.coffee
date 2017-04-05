express = require('express')
path = require('path')
logger = require('morgan')
cookieParser = require('cookie-parser')
bodyParser = require('body-parser')
hbs = require('express-handlebars')
expressValidator = require('express-validator')
expressSession = require('express-session')
mongoose = require('mongoose')
routes = require('./routes/index')
config = require('./config')
app = express()
mongoose.connect config.database
# view engine setup
app.engine 'hbs', hbs(
  extname: 'hbs'
  defaultLayout: 'layout'
  layoutsDir: __dirname + '/views/layouts/')
app.set 'views', path.join(__dirname, 'views')
app.set 'view engine', 'hbs'
app.use logger('dev')
app.use bodyParser.json()
app.use bodyParser.urlencoded(extended: false)
app.use expressValidator()
app.use cookieParser()
app.use express.static(path.join(__dirname, 'public'))
app.use expressSession(
  secret: 'redX'
  saveUninitialized: false
  resave: false)
app.use '/', routes
# catch 404 and forward to error handler
app.use (req, res, next) ->
  err = new Error('Not Found')
  err.status = 404
  next err
  return
# error handler
app.use (err, req, res, next) ->
  # set locals, only providing error in development
  res.locals.message = err.message
  res.locals.error = if req.app.get('env') == 'development' then err else {}
  # render the error page
  res.status err.status or 500
  res.render 'error'
  return
module.exports = app