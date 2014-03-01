###
Word index model
================

Index of words in terms

###

mongoose    = require "mongoose"
$           = (require "debug") "ufs:model:word-index"
# _           = require "underscore"

# Occurence = new mongoose.Schema
#   # Term in which a word occurs
#   term        :
#     type        : mongoose.Schema.ObjectId
#     ref         : 'Term'
#   # Position of the word (first, second, etc)
#   position    : [ Number ]    

Index = new mongoose.Schema
  _id         : # The word itself
    type        : String
  length      : # Length of the word - used to prefilter index before calculating Damerau - Levenshtein distancese
    type        : Number
    index       : yes
  volume      : # How many of this word is there in our data set (how common is it)
    type        : Number
  terms       : # Terms for which text contains this word
    type        : [ Number ]
    ref         : 'Term'

module.exports = mongoose.model 'fulltext.index', Index