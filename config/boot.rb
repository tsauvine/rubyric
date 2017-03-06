ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# require 'rubygems'
#
# # Temporary fix for the "couldn't parse YAML at line" problem
# require 'yaml'
# # YAML::ENGINE.yamler = 'syck'
#
# # Set up gems listed in the Gemfile.
# ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
#
# require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
