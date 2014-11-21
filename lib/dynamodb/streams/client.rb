require 'json'
require 'openssl'
require 'net/http'
require 'net/https'
require 'time'
require 'stringio'
require 'zlib'
require 'uri'

require 'thor'

require 'dynamodb/streams/client/version'
require 'dynamodb/streams/client/cli'

class DynamoDB::Streams::Client
  class Error < StandardError
    attr_reader :data

    def initialize(error_message, data = {})
      super(error_message)
      @data = data
    end
  end

  SERVICE_NAME = 'dynamodb'
  API_VERSION  = '2012-08-10'
  USER_AGENT   = "dynamodb-streams-client/#{DynamoDB::Streams::Client::VERSION}"

  DEFAULT_TIMEOUT = 60

  attr_accessor :timeout
  attr_accessor :retry_num
  attr_accessor :retry_intvl
  attr_accessor :debug

  def initialize(options)
    @accessKeyId = options.fetch(:access_key_id)
    @secretAccessKey = options.fetch(:secret_access_key)
    @endpoint = URI.parse(options.fetch(:endpoint))
    @region = options[:region]

    unless @region or @region = (/([^.]+)\.amazonaws\.com\z/.match(@endpoint.host) || [])[1]
      @region = [@endpoint.host, @endpoint.port].join(':')
    end

    @timeout = DEFAULT_TIMEOUT
    @debug = false
    @retry_num = 3
    @retry_intvl = 10
  end

  def query(action, hash = {})
    retry_query do
      query0(action, hash)
    end
  end

  def query0(action, hash)
    req_body = JSON.dump(hash)
    date = Time.now.getutc

    headers = {
      'Content-Type'         => 'application/x-amz-json-1.0',
      'X-Amz-Target'         => "DynamoDBStreams_#{API_VERSION.gsub('-', '')}.#{action}",
      'Content-Length'       => req_body.length.to_s,
      'User-Agent'           => USER_AGENT,
      'Host'                 => @endpoint.host,
      'X-Amz-Date'           => iso8601(date),
      'X-Amz-Content-Sha256' => hexhash(req_body),
      'Accept'               => '*/*',
      'Accept-Encoding'      => 'gzip',
    }

    headers['Authorization'] = authorization(date, headers, req_body)

    Net::HTTP.version_1_2
    http = Net::HTTP.new(@endpoint.host, @endpoint.port)

    if @endpoint.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    if @debug
      http.set_debug_output($stderr)
    end

    http.open_timeout = @timeout
    http.read_timeout = @timeout

    res_code = nil
    res_msg  = nil

    res_body = http.start do |w|
      req = Net::HTTP::Post.new('/', headers)
      req.body = req_body
      res = w.request(req)

      res_code = res.code.to_i
      res_msg  = res.message

      if res['Content-Encoding'] == 'gzip'
        StringIO.open(res.body, 'rb') do |f|
          Zlib::GzipReader.wrap(f).read
        end
      else
        res.body
      end
    end

    res_data = JSON.parse(res_body)
    __type = res_data['__type']

    if res_code != 200 or __type
      errmsg = if __type
                 if @debug
                   "#{__type}: #{res_data['message'] || res_data['Message']}"
                 else
                   "#{res_data['message'] || res_data['Message']}"
                 end
               else
                 "#{res_code} #{res_msg}"
               end

      raise DynamoDB::Streams::Client::Error.new(errmsg, res_data)
    end

    res_data
  end

  private

  def authorization(date, headers, body)
    headers = headers.sort_by {|name, value| name }

    # Task 1: Create a Canonical Request For Signature Version 4
    # http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

    canonicalHeaders = headers.map {|name, value|
      name.downcase + ':' + value
    }.join("\n") + "\n"

    signedHeaders = headers.map {|name, value| name.downcase }.join(';')

    canonicalRequest = [
      'POST', # HTTPRequestMethod
      '/',    # CanonicalURI
      '',     # CanonicalQueryString
      canonicalHeaders,
      signedHeaders,
      hexhash(body),
    ].join("\n")

    # Task 2: Create a String to Sign for Signature Version 4
    # http://docs.aws.amazon.com/general/latest/gr/sigv4-create-string-to-sign.html

    credentialScope = [
      date.strftime('%Y%m%d'),
      @region,
      SERVICE_NAME,
      'aws4_request',
    ].join('/')

    stringToSign = [
      'AWS4-HMAC-SHA256', # Algorithm
      iso8601(date),      # RequestDate
      credentialScope,
      hexhash(canonicalRequest),
    ].join("\n")

    # Task 3: Calculate the AWS Signature Version 4
    # http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html

    kDate     = hmac('AWS4' + @secretAccessKey, date.strftime('%Y%m%d'))
    kRegion   = hmac(kDate, @region)
    kService  = hmac(kRegion, SERVICE_NAME)
    kSigning  = hmac(kService, 'aws4_request')
    signature = hexhmac(kSigning, stringToSign)

    'AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s' % [
      @accessKeyId,
      credentialScope,
      signedHeaders,
      signature,
    ]
  end

  def iso8601(utc)
    utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def hexhash(data)
    OpenSSL::Digest::SHA256.new.hexdigest(data)
  end

  def hmac(key, data)
    OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, key, data)
  end

  def hexhmac(key, data)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, key, data)
  end

  def retry_query
    retval = nil

    (@retry_num + 1).times do |i|
      begin
        retval = yield
        break
      rescue Errno::ETIMEDOUT => e
        raise e if i >= @retry_num
      rescue DynamoDB::Streams::Client::Error => e
        if [/\bServiceUnavailable\b/i, /\bexceeded\b/i].any? {|i| i =~ e.message }
          raise e if i >= @retry_num
        else
          raise e
        end
      rescue Timeout::Error => e
        raise e if i >= @retry_num
      end

      wait_sec = @retry_intvl * (i + 1)

      if @debug
        $stderr.puts("Retry... (wait %d seconds)" % wait_sec)
      end

      sleep wait_sec
    end

    return retval
  end
end
