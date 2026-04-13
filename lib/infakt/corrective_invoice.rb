class Infakt
  class CorrectiveInvoice < Base
    URL = "https://api.infakt.pl/v3/corrective_invoices.json"

    def self.create(attributes)
      Request.new(URL, data: { corrective_invoice: attributes }).post
    end
  end
end
