# Requires
require "coffee-script/register" # Needed for .coffee modules

mongo = require("mongodb").MongoClient
assert = require "assert"
express = require "express"
Pusher = require "pusher"
Trello = require "node-trello"

# Helper classes
__ = require "#{ __dirname }/../lib/__"
logger = require("tracer").colorConsole()

# Determine config
config = __.config()

app = express()
http = require("http").Server(app)

# Datastore
save = require("save")

Events = save("event")
Users = save("user")
Recipes = save("recipe")

# Express settings
app.use require("compression")()
app.use require("body-parser").json({ strict: false })
app.set 'json spaces', 2

# Trello setup
t = new Trello("8bd0662b8bb4434a08917d303d4aeb59", "4cebf5edcf258f109a44df7af08deac210422013d2295f0a43b65a510b730dd6")

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
    event_image: req.body.event_image,
    user_id: req.body.user_id

  Events.create event, (err, msg) ->
    res.json msg

app.post "/recipe", (req, res) ->
  logger.info req.body
  body = req.body

  if body.recipe_type not in ["when", "on"]
    res.json
      message: "Invalid type"
    return

  if body.recipe_output not in ["trello"]
    res.json
      message: "No output!"
    return

  if body.operator not in ["<", ">", "==", "!="]
    re.json
      message: "Invalid operator"

  recipe =
    recipe_name: body.recipe_name,
    recipe_type: body.recipe_type
    recipe_input: body.recipe_input,
    recipe_output: body.recipe_output,
    recipe_condition:
      operator: body.operator,
      comparison: body.comparison

  Recipes.create recipe, (err, msg) ->
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
    error: err

# REAL TIME API
# =============

# Active user change
emitActiveUser = (io) ->
  ActiveUsers.find {}, (err, users) ->
    io.emit "users/active", users

Events.on "create", (event) ->
  # Send crash log to Trello
  if event.event_name is "crash"
    t.post '/1/card',
      name: 'That\s a crash yo.',
      idList: '54d73f9545f7fe3e0963c365',
      idMembers: '5079a24a705b65b55a00731c',
      desc: event.event_body
    , (err, data) -> console.log data

Events.on "create", (event) ->
  logger.info event
  Recipes.findOne {recipe_input: event.event_name}, (err, recipe) ->
    if err != undefined
      logger.warn err
      return

    logger.info recipe

    recipe_condition = recipe.recipe_condition
    recipe_output = recipe.recipe_output

    gotCompared = (err, comparison) ->
      logger.info "Comparing " + event.event_value + recipe_condition.operator + comparison
      if recipe_condition.operator == "<"
        if not (event.event_value < comparison)
          return
      if recipe_condition.operator == ">"
        if not (event.event_value > comparison)
          return
      if recipe_condition.operator == "=="
        if not (event.event_value == comparison)
          return
      if recipe_condition.operator == "!="
        if not (event.event_value != comparison)
          return

      logger.info "Trigger Output"
      logger.info recipe_output
      pusher.trigger 'recipes', recipe_output, {"message": "Holly crap it works!"}


    if (recipe_condition.comparison.indexOf '$') == 0
      logger.info 'Event value'
      comparison = recipe_condition.comparison.substring 1
      comparison = Events.find {event_name: comparison}, (err, objs) ->
        obj = objs.sort((a,b) -> b.at-a.at)[0]
        gotCompared err obj.event_value
    else
      logger.info 'Static value'
      comparison = parseInt(recipe_condition.comparison, 10)
      gotCompared undefined, comparison



pusher.trigger 'channel-1', 'test_event', message: 'hello world'

# Run server and return object
# ============================
server = http.listen config.PORT, ->
  logger.info "👂  Listening on port %d", server.address().port

return server # return for testing