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

## CLI

```sh
$ dynamodb-streams
Commands:
  dynamodb-streams describe_stream STREAM_ID                                  # Returns information about a stream
  dynamodb-streams get_records SHARD_ITERATOR                                 # Retrieves the stream records
  dynamodb-streams get_shard_iterator STREAM_ID SHARD_ID SHARD_ITERATOR_TYPE  # Returns a shard iterator
  dynamodb-streams help [COMMAND]                                             # Describe available commands or one specific command
  dynamodb-streams list_streams                                               # Returns an array of stream IDs

Options:
  -k, [--access-key=ACCESS-KEY]
  -s, [--secret-key=SECRET-KEY]
  -e, [--endpoint=ENDPOINT]
  -r, [--region=REGION]
```

### Follow record

```sh
dynamodb-streams get_records xxxxxxxx-xxxx-... -f --limit 10
```
