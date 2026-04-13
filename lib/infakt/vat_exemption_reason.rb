class Infakt
  class VatExemptionReason < Base
    URL = "https://api.infakt.pl/v3/vat_exemptions.json?offset=0"

    def self.url
      URL
    end

    def self.list
      result = Request.new(URL).get
      entities = result['entities']
      while result['metainfo']['count'] > 0
        url = result['metainfo']['next']
        result = Request.new(url).get
        entities += result['entities']
      end

      entities
    end
  end
end
