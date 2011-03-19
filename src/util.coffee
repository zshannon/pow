# The `util` module houses a number of utility functions used
# throughout Pow.

fs    = require "fs"
path  = require "path"
async = require "async"

{Stream} = require 'stream'

# The `LineBuffer` class is a `Stream` that emits a `data` event for
# each line in the stream.
exports.LineBuffer = class LineBuffer extends Stream
  # Create a `LineBuffer` around the given stream.
  constructor: (@stream) ->
    @readable = true
    @_buffer = ""

    # Install handlers for the underlying stream's `data` and `end`
    # events.
    self = this
    @stream.on 'data', (args...) -> self.write args...
    @stream.on 'end',  (args...) -> self.end args...

  # Write a chunk of data read from the stream to the internal buffer.
  write: (chunk) ->
    @_buffer += chunk

    # If there's a newline in the buffer, slice the line from the
    # buffer and emit it. Repeat until there are no more newlines.
    while (index = @_buffer.indexOf("\n")) != -1
      line     = @_buffer[0...index]
      @_buffer = @_buffer[index+1...@_buffer.length]
      @emit 'data', line

  # Process any final lines from the underlying stream's `end`
  # event. If there is trailing data in the buffer, emit it.
  end: (args...) ->
    if args.length > 0
      @write args...
    @emit 'data', @_buffer if @_buffer.length
    @emit 'end'

# Read lines from `stream` and invoke `callback` on each line.
exports.bufferLines = (stream, callback) ->
  buffer = new LineBuffer stream
  buffer.on "data", callback
  buffer

# ---

# Escape meaningful HTML characters in a string.
exports.escapeHTML = (string) ->
  string.toString()
    .replace(/&/g,  "&amp;")
    .replace(/</g,  "&lt;")
    .replace(/>/g,  "&gt;")
    .replace(/\"/g, "&quot;")

# Asynchronously and recursively create a directory if it does not
# already exist. Then invoke the given callback.
exports.mkdirp = (dirname, callback) ->
  fs.lstat (p = path.normalize dirname), (err, stats) ->
    if err
      paths = [p].concat(p = path.dirname p until p in ["/", "."])
      async.forEachSeries paths.reverse(), (p, next) ->
        path.exists p, (exists) ->
          if exists then next()
          else fs.mkdir p, 0755, (err) ->
            if err then callback err
            else next()
      , callback
    else if stats.isDirectory()
      callback()
    else
      callback "file exists"

# Capture all `data` events on the given stream and return a function
# that, when invoked, replays the captured events on the stream in
# order.
exports.pause = (stream) ->
  queue = []

  onData  = (args...) -> queue.push ['data', args...]
  onEnd   = (args...) -> queue.push ['end', args...]
  onClose = -> removeListeners()

  removeListeners = ->
    stream.removeListener 'data', onData
    stream.removeListener 'end', onEnd
    stream.removeListener 'close', onClose

  stream.on 'data', onData
  stream.on 'end', onEnd
  stream.on 'close', onClose

  ->
    removeListeners()

    for args in queue
      stream.emit args...
