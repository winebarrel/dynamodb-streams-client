require 'deep_merge'

class DynamoDB::Streams::Client::CLI < Thor
  ITOR_WAIT = 0.3

  class_option 'access-key', :aliases => '-k'
  class_option 'secret-key', :aliases => '-s'
  class_option 'endpoint',   :aliases => '-e'
  class_option 'region',     :aliases => '-r'

  desc 'list_streams', 'Returns an array of stream IDs'
  def list_streams
    res_data = iterate('StreamId') do |rh|
      client.query('ListStreams', rh)
    end

    puts JSON.pretty_generate(res_data)
  end

  desc 'describe_stream STREAM_ID', 'Returns information about a stream'
  def describe_stream(stream_id)
    req_hash = {'StreamId' => stream_id}

    res_data = iterate('ShardId', req_hash) do |rh|
      client.query('DescribeStream', rh)
    end

    puts JSON.pretty_generate(res_data)
  end

  desc 'get_shard_iterator STREAM_ID SHARD_ID SHARD_ITERATOR_TYPE', 'Returns a shard iterator'
  option 'sequence-number'
  def get_shard_iterator(stream_id, shard_id, shard_iterator_type)
    req_hash = {
      'StreamId'          => stream_id,
      'ShardId'           => shard_id,
      'ShardIteratorType' => shard_iterator_type.upcase,
    }

    if seq_num = options['sequence-number']
      req_hash['SequenceNumber'] = seq_num
    end

    res_data = client.query('GetShardIterator', req_hash)
    puts JSON.pretty_generate(res_data)
  end

  desc 'get_records SHARD_ITERATOR', 'Retrieves the stream records'
  option 'limit', :type => :numeric
  option 'follow', :aliases => '-f'
  def get_records(shard_iterator)
    req_hash = {'ShardIterator' => shard_iterator}
    req_hash['Limit'] = options['limit'] if options['limit']

    loop do
      res_data = client.query('GetRecords', req_hash)
      puts JSON.pretty_generate(res_data)
      next_shard_iterator = res_data['NextShardIterator']

      unless options['follow'] and next_shard_iterator
        break
      end

      req_hash['ShardIterator'] = next_shard_iterator
    end
  end

  no_commands do
    def iterate(item, req_hash = {})
      res_data = {}

      list = proc do |last_evaluated|
        req_hash["ExclusiveStart#{item}"] = last_evaluated if last_evaluated
        resp = yield(req_hash)
        res_data.deep_merge!(resp)
        resp["LastEvaluated#{item}"]
      end

      le = nil

      loop do
        le = list.call(le)
        break unless le
      end

      res_data.delete("LastEvaluated#{item}")
      res_data
    end

    def client
      return @client if @client

      client_options = {
        :access_key_id     => options.fetch('access-key', ENV['AWS_ACCESS_KEY_ID']),
        :secret_access_key => options.fetch('secret-key', ENV['AWS_SECRET_ACCESS_KEY']),
        :endpoint          => options.fetch('endpoint',   ENV['DYNAMODB_STREAMS_ENDPOINT']),
        :region            => options['region'],
      }

      @client = DynamoDB::Streams::Client.new(client_options)
    end
  end
end
