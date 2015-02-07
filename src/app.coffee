# Requires
require "coffee-script/register" # Needed for .coffee modules
require "longjohn" if process.env.NODE_ENV isnt "production"

express = require "express"

# Helper classes
__ = require "#{ __dirname }/../lib/__"
logger = require("tracer").colorConsole()

# Determine config
config = __.config()

app = express()
http = require("http").Server(app)
io = require("socket.io")(http)

# Express settings
app.use require("compression")()
app.use require("body-parser").json({ strict: false })
app.set 'json spaces', 2

# Fix json error
app.use (req, res, next) ->
  req.body = JSON.parse req.body if typeof req.body is "string"
  next()

# Datastore
save = require("save")

# LOADERIO VERIFICATION
# =====================
app.get "/loaderio-fa1db6b2da5f4b83300113acc45c8a06/", (req, res) ->
  res.send "loaderio-fa1db6b2da5f4b83300113acc45c8a06"

app.get "/test-data.json", (req, res) ->
  res.json require "#{ __dirname }/../test-data.json"

# ROOT
# ====
app.get "/", (req, res) ->
  res.json
    status: 200
    spec: "https://github.com/ryanbrodie/Momentum"

# Deauthorisation request
# -----------------------
app.delete "/auth", (req, res, next) ->
  Tokens.deleteMany { token: req.token }, (err) ->
    return res.json({ success: "Token destroyed" })

# MESSAGE PASSING
# ===============

# Create message
# --------------
app.post "/message", (req, res, next) ->
  if not req.body? or not req.body.message?
    err = new Error("No message provided")
    err.status = 400
    return next err

  message =
    message: req.body.message
    from: req.username
    at: Date.now()

  Messages.create message, (err, message) ->
    res.json message

# Get recent messages
# -------------------
app.get "/messages", (req, res, next) ->
  Messages.find {}, (err, messages) ->
    res.json messages

# USERS
# =====

# Create user
# -----------
app.post "/user", (req, res, next) ->
  if not req.body? or not req.body.username? or not req.body.password?
    err = new Error("Missing username or password")
    err.status = 400
    return next err

  Users.findOne { username: req.body.username }, (err, user) ->
    if user isnt undefined
      err = new Error("User already exists with that username")
      err.status = 400
      return next err

    user =
      username: req.body.username
      password: req.body.password

    Users.create user, (err, user) ->
      res.json({ success: "User created" })

# Get active users
# ----------------
app.get "/users/active", (req, res, next) ->
  ActiveUsers.find {}, (err, users) ->
    res.json users

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

  socket.on "anything", (data) ->
    socket.emit data
    logger.info data

  socket.on "disconnect", ->
    logger.info "User disconnected."

# Run server and return object
# ============================
server = http.listen config.PORT, ->
  logger.info "👂  Listening on port %d", server.address().port

return server # return for testing