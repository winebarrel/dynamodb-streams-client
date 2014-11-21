# Dynamodb::Streams::Client

[DynamoDB Streams](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html) client.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dynamodb-streams-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dynamodb-streams-client

## Usage

```ruby
require 'dynamodb/streams/client'
require 'pp'

client = DynamoDB::Streams::Client.new(
  access_key_id: 'YOUR_ACCESS_KEY_ID',
  secret_access_key: 'YOUR_SECRET_ACCESS_KEY',
  endpoint: '...')

#client.debug = true

pp client.query('ListStreams')
#=> {"StreamIds"=>
#     ["...",
#      "...",
#      "..."]}
```
