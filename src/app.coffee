# Requires
require "coffee-script/register" # Needed for .coffee modules

mongo = require("mongodb").MongoClient
assert = require "assert"
express = require "express"
Pusher = require "pusher"

# Helper classes
__ = require "#{ __dirname }/../lib/__"
logger = require("tracer").colorConsole()

# Determine config
config = __.config()

app = express()
http = require("http").Server(app)

# Datastore
save = require("save")

Events = save("events")
Users = save("users")
Recipes = save("recipes")

# Express settings
app.use require("compression")()
app.use require("body-parser").json({ strict: false })
app.set 'json spaces', 2

# Pusher setup
pusher = new Pusher
  appId: '106421',
  key: '25ec6b2cb63f36185bc1',
  secret: 'b3e639f8b89eed3b8e78'

# Fix json error
app.use (req, res, next) ->
  req.body = JSON.parse req.body if typeof req.body is "string"
  next()

# Event Checking

# ROOT
# ====
app.get "/", (req, res) ->
  res.json
    status: 200
    spec: "https://github.com/ryanbrodie/Momentum"


# EVENT API
# =========
app.post "/events", (req, res) ->
  logger.info req.body
  pusher.trigger 'actions', 'test_event', req.body

  event =
    at: Date.now(),
    event_name: req.body.event_name,
    event_type: req.body.event_type,
    event_value: req.body.event_value,
    event_body: req.body.event_body,
    user_id: req.body.user_id

  Events.create event, (err, msg) ->
    res.json msg

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

pusher.trigger 'channel-1', 'test_event', message: 'hello world'

# io.on "connection", (socket) ->
#   logger.info "Someone connected!"
#   socket.emit "event", { hello: "world" }

#   socket.on "event", (data) ->
#     if data.event_name? and data.event_name is "app_open"
#       socket.emit "push", { message: "Yo!" }
#     logger.info data

#   socket.on "disconnect", ->
#     logger.info "User disconnected."

# Run server and return object
# ============================
server = http.listen config.PORT, ->
  logger.info "👂  Listening on port %d", server.address().port

return server # return for testing