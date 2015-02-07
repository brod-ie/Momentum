# Requires
require "coffee-script/register" # Needed for .coffee modules

mongo = require("mongodb").MongoClient
assert = require "assert"
express = require "express"

# Helper classes
__ = require "#{ __dirname }/../lib/__"
logger = require("tracer").colorConsole()

# Determine config
config = __.config()

app = express()
http = require("http").Server(app)
io = require("socket.io")(http)

mongo.connect config.MONGOLAB_URI, (err, db) ->
  assert.equal null, err
  console.log 'Connected correctly to server'
  db.close()

# Express settings
app.use require("compression")()
app.use require("body-parser").json({ strict: false })
app.set 'json spaces', 2

# Fix json error
app.use (req, res, next) ->
  req.body = JSON.parse req.body if typeof req.body is "string"
  next()

# ROOT
# ====
app.get "/", (req, res) ->
  res.json
    status: 200
    spec: "https://github.com/ryanbrodie/Momentum"

# ERROR HANDLING
# ==============

# Not found
app.use (req, res, next) ->
  err = new Error("Not found")
  err.status = 404
  next err

# Error handler fn
app.use (err, req, res, next) ->
  res.status err.status or 500
  res.json
    error: err.message

# REAL TIME API
# =============

io.on "connection", (socket) ->
  logger.info "Someone connected!"
  socket.emit "event", { hello: "world" }

  socket.on "event", (data) ->
    if data.event_name? and data.event_name is "app_open"
      socket.emit "push", { message: "Yo!" }
      logger.info "Holy crap someone opened our app!"
    logger.info data

  socket.on "disconnect", ->
    logger.info "User disconnected."

# Run server and return object
# ============================
server = http.listen config.PORT, ->
  logger.info "👂  Listening on port %d", server.address().port

return server # return for testing