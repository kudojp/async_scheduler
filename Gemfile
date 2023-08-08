# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in async_scheduler.gemspec
gemspec
# TODO: move this to gemspec file.
# Also, remove `require: "nonblocking/resolv"`. I don't know how to clean this up now.
# gem "nonblocking-resolv", :github => 'kudojp/nonblocking-resolv'
gem "nonblocking-resolv", path: "../nonblocking-resolv"

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rubocop", "~> 1.21"

# TODO: Remove gems below before releasing!
gem 'pry'
gem 'pry-doc'
gem 'pry-byebug'
gem 'pry-stack_explorer'
