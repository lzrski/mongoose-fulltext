###
Term model
==========

Single prohibited contract term from the register

###

mongoose    = require "mongoose"
async       = require "async"
_           = require "underscore"
_.words     = require "underscore.string.words"
Index       = require "./Index"
Similar     = require "./Similar"

debug       = require "debug"
$           = debug "ufs:model:Term"

Term = new mongoose.Schema
  _id         : # Number of term in register
    type        : Number
  text        : 
    type        : String
    required    : yes
  original_uri:
    type        : String


Term.static "findByText", (query, options = {}, callback) ->
  # Query can be 
  # * String    - as entered by user
  # * [String]  - Array of words, will be sanitized

  # Options is a dictionary. Possible values:
  # * limit     - maximal number of matching terms, default 20

  # Callback is a function with signature like so:
  # * error
  # * matches   - array of matching terms {term, rank}
  # * quantity  - number of matched terms (before limit is applied)
  # * words     - words extracted from query

  $ = debug "ufs:model:Term:findByText"

  defaults  =
    limit     : 20

  if typeof options is 'function'
    callback  = options
    options   = defaults
  else
    options = _.defaults options, defaults

  words     = []

  if query instanceof Array
    words.concat _.words s for s in query
  else 
    words = _.unique (_.words query)

  if not words
    $ "No words in query: %pj", words
    return callback Error "Empty query"

  async.waterfall [
    # Step 1: prepare ranking
    (done) ->
      ranking   = {} # { term: rank } dictionary

      async.each words,
        (word, done) ->
          terms = [] # Terms yield by this word

          Similar.getSimilar word, (error, similar) ->
            $ "Got %d words similar to '%s'", similar.length, word
            async.each similar,
              (similar_word, done) ->
                # Get terms for this similar word
                Index.findById similar_word._id, (error, entry) ->
                  if error      then done error
                  if not entry  then return do done
                  $ "Word %s: %j", similar_word, entry
                  terms = _.union terms, entry.terms

                  do done

              (error) ->
                # Here we are after each similar word is looked up
                # and all the terms yield for this excact word are stored in terms array
                if error then done error

                value = 1 / terms.length # relative value of this word
                for term in terms 
                  if not ranking[term]? then ranking[term] = 0
                  ranking[term] += value

                do done

        (error) ->
          # Here all the words from query were looked up
          # The ranking is ready
          done error, ranking
    
    # step 2: get actual terms based on ranking
    (ranking, done) =>
      ranking   = _.sortBy ({term_id, rank} for term_id, rank of ranking), "rank"
      $ "Ranking is: ", ranking
      # [{term_id: rank}, {term_id: rank}, ...]
      quantity  = ranking.length
      ranking   = ranking.slice(-options.limit)

      ids = (position.term_id for position in ranking) # array of term ids
      $ "Looking for terms with ids: %j",  ids
      @find _id: $in: ids, (error, terms) ->
        if error then return done error
        $ "Got %d terms", terms.length
        terms = _.map ranking, (position) ->
          term = _.find terms, (term) -> term.id is position.term_id
          _.extend term.toObject(), position

        # $ "%d", terms[0].rank
        done null, (_.sortBy terms, "rank").reverse()
  ], callback  

Term.post "save", (term) ->
  words = _.words term.text

  async.each words,
    (word, done) ->
      Index.update { _id: word },
        {
          $addToSet:
            terms: term
          $inc:
            volume: 1
          length: word.length
        }
        { upsert: true }
        (error, number, response) ->
          if error then return done error
          if not response.updatedExisting
            $ "New word discovered: #{word}"
          do done
    (error) ->
      if error then throw error

module.exports = mongoose.model 'Term', Term