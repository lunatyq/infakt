class Infakt
  class InvoiceStatus < Base
    vattr_initialize :invoice_task_reference_number

    def status
      Request.new(url).get
    end

    def url
      "https://api.infakt.pl/v3/async/invoices/status/#{invoice_task_reference_number}.json"
    end
  end
end
