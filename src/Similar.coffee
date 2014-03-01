###

Similarity Cache model
======================

Cached damerau - levenshtein distances and similarities for words in queries

###

mongoose    = require "mongoose"
Index       = require "./Index"
_           = {}
_.words     = require "underscore.string.words"
dld         = require "damerau-levenshtein"
async       = require 'async'
$           = (require "debug") "ufs:model:similarities"

Similar     = new mongoose.Schema
  _id       : String
  distance  : Number
  similarity: Number

Cache  = new mongoose.Schema
  _id       : 
    type      : String
  similar   : [ Similar ]

tolerance = 
  steps     : 2
  similarity: 0.7

Cache.static "getSimilar", (lookup, callback) ->
  $ "Getting words similar to '#{lookup}'"
  if (lookup.match _.words.re)[0] isnt lookup
    $ "Not a word: '#{lookup}'"
    return callback Error "Please provide a single lowercase word"

  @findById lookup, (error, word) =>
    $ "Looking for #{lookup}"
    if error  then return callback error
    if word   then return callback null, word.similar
    else 
      word = new @ _id: lookup
      $ "'%s' not found in cache. Calculating: %j", lookup, word
      
      Index.find { 
        length:
          # Optimize. If difference in length is grater then n then dld is also greater
          # TODO: run it only once for each distinct word length
          $gte: lookup.length - tolerance.steps
          $lte: lookup.length + tolerance.steps
      }, (error, candidates) ->
        if error then return callback error
        $ "Prefilter for '%s' returned %d results", lookup, candidates.length
        async.each candidates,
          (candidate, next) ->
            distance  = dld candidate._id, lookup
            # $ "trying %s\t: %s\t %d\t %d", lookup, candidate._id, distance.steps, distance.similarity
          
            if  (distance.similarity >= tolerance.similarity) and
                (distance.steps      <= tolerance.steps)
                  $ "'%s' is similar to '%s' \t(%d \t%d)",
                    lookup
                    candidate._id
                    distance.steps
                    distance.similarity

                  similar         = distance
                  similar._id     = candidate._id
                  word.similar.push similar

            do next

          (error) ->
            if error then return callback error

            $ "Done calculating similarities to '%s'. %d found.",
              lookup
              word.similar.length

            word.save (error) ->
              if error then return callback error

              return callback null, word.similar
          
      

module.exports = mongoose.model 'fulltext.cache', Cache