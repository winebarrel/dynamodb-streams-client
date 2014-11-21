require 'deep_merge'

class DynamoDB::Streams::Client::CLI < Thor
  class_option 'access-key', :aliases => '-k'
  class_option 'secret-key', :aliases => '-s'
  class_option 'endpoint',   :aliases => '-e'
  class_option 'region',     :aliases => '-r'

  desc 'list_streams', 'Returns an array of stream IDs'
  def list_streams
    req_hash = {}
    res_data = {}

    list = lambda do |last_evaluated_stream_id|
      req_hash['ExclusiveStartStreamId'] = last_evaluated_stream_id if last_evaluated_stream_id
      resp = client.query('ListStreams', req_hash)
      res_data.deep_merge!(resp)
      req_hash['LastEvaluatedStreamId']
    end

    lesi = nil

    loop do
      lesi = list.call(lesi)
      break unless lesi
    end

    puts JSON.pretty_generate(res_data)
  end

  no_commands do
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
