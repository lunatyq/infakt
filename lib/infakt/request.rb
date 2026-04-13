class Infakt
  class Request
    vattr_initialize :url, [:data, :raw_response, :no_response]

    def https
      @https ||= Net::HTTP.new(uri.host, uri.port).tap do |https|
        https.use_ssl = true
      end
    end

    def delete
      perform_request(Net::HTTP::Delete)
    end

    def get
      perform_request(Net::HTTP::Get)
    end

    def post
      perform_request(Net::HTTP::Post)
    end

    def put
      perform_request(Net::HTTP::Put)
    end

    def perform_request(klass)
      request = klass.new(uri)

      request["X-inFakt-ApiKey"] = ENV["INFAKT_API_KEY"]
      request['Content-Type'] = 'application/json'
      if data
        request.body = data.to_json # JSON.pretty_generate(data) #.to_json
      end
      response = https.request(request)

      return if no_response

      if raw_response
        response.read_body
      else
        JSON.parse(response.read_body)
      end
    end

    def uri
      URI.parse(url)
    end
  end
end
