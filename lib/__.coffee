# Helper class
class __

  config: ->
    return process.env if process.env.ENVIRONMENT?
    return require "#{ __dirname }/../../Momentum.json"

module.exports = new __