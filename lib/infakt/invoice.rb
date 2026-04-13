class Infakt
  class Invoice < Base
    URL = "https://api.infakt.pl/v3/invoices.json"
    ENTITY_URL = "https://api.infakt.pl/v3/invoices/{{invoice_uuid}}.json"
    PAID_URL = "https://api.infakt.pl/v3/invoices/{{invoice_uuid}}/paid.json"
    PRINT_URL = "https://api.infakt.pl/v3/invoices/{{invoice_uuid}}/pdf.json"

    def self.url
      URL
    end

    def self.create(attributes)
      Request.new(URL, data: { invoice: attributes }).post
    end

    def self.print(invoice)
      url = uuid_url(PRINT_URL, invoice['uuid'])
      Request.new(url, data: { document_type: 'original' }, raw_response: true).get
    end

    def self.paid(invoice, paid_on)
      url = uuid_url(PAID_URL, invoice['uuid'])
      Request.new(url, data: { invoice: { paid_date: paid_on} }).post
    end

    def self.update(invoice, changes = {})
      url = uuid_url(ENTITY_URL, invoice['uuid'])
      Request.new(url, data: { invoice: changes }).put
    end

    def self.list(limit = 10)
      puts URL + "?limit=#{limit}"
      Request.new(URL + "?limit=#{limit}").get
    end

    def self.delete(invoice)
      puts invoice['uuid']
      url = uuid_url(ENTITY_URL, invoice['uuid'])
      Request.new(url, :no_response => true).delete
    end

    def self.find(number)
      url = "#{URL}?q[number_eq]=#{number}"
      result = Request.new(url).get
      if result['error']
        raise result.inspect
      end

      if result['metainfo']['count'] > 0
        result["entities"]
      else
        []
      end
    end

    def self.uuid_url(url, uuid)
      url.sub("{{invoice_uuid}}", uuid)
    end
  end
end
