⚠️ This project is still work in progress, and not published as a gem yet.

# AsyncScheduler

[![CI](https://github.com/kudojp/async_scheduler/actions/workflows/ci.yaml/badge.svg)](https://github.com/kudojp/async_scheduler/actions/workflows/ci.yaml)
[![codecov](https://codecov.io/gh/kudojp/async_scheduler/branch/main/graph/badge.svg?token=1JZU04RYFD)](https://codecov.io/gh/kudojp/async_scheduler)
[![License](https://img.shields.io/github/license/kudojp/async_scheduler)](./LICENSE)

This is a Fiber Schduler, which is a missing piece to do concurrent programming in Ruby language.  
If you are not familiar with the concept of Fiber Schduler, please refer to my presentation: [Ruby の FiberScheduler を布教したい](https://speakerdeck.com/kudojp/ruby-false-fiberscheduler-wobu-jiao-sitai). (Sorry in Japanese.)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'async_scheduler'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install async_scheduler
```

## Usage

Set this scheduler in the current thread.
Then, surround the blocking oerations in `Fiber.schedule` block so  that they are executed concurrently.

```rb
Fiber.set_schduler AsyncScheduler::Scheduler.new

Fiber.schedule do
  File.read("file1.txt") # some blocking operation
end

Fiber.schedule do
  File.read("file2.txt") # some blocking operation
end

puts "Finished"
```


## Development

Add and run spec.

```
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kudojp/async_scheduler. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/kudojp/async_scheduler/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AsyncScheduler project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/async_scheduler/blob/master/CODE_OF_CONDUCT.md).
