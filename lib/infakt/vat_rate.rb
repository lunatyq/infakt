class Infakt
  class VatRate < Base
    URL = "https://api.infakt.pl/api/v3/vat_rates.json"

    def self.url
      URL
    end

    def self.list
      Request.new(URL).get
    end
  end
end
