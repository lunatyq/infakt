require 'spec_helper'

RSpec.describe Infakt::PreKsefInvoiceData do
  let(:raw_data) do
    JSON.parse(
      File.read("data/invoices/2026/03/3924.2026.json"),
      symbolize_names: true
    )
  end

  subject { described_class.new(raw_data) }

  describe '#attributes' do
    let(:attrs) { subject.attributes }

    it 'builds full infakt payload' do
      expect(attrs).to include(
        number: "3924/2026",
        currency: "PLN",
        kind: "vat",
        payment_method: "transfer",
        seller_signature: "Maciej Tomaka",
        invoice_date: "2026-03-12",
        sale_date: "2026-03-12",
        payment_date: "2026-03-12",
        paid_date: nil,
        net_price: 142800,
        tax_price: 32844,
        gross_price: 175644,
        left_to_pay: 175644,
        client_company_name: "Agencja Oceny Technologii Medycznych i Taryfikacji",
        client_street: "Przeskok 2",
        client_street_number: "",
        client_flat_number: "",
        client_country: "PL",
        client_city: "Warszawa",
        client_post_code: "00-032",
        client_tax_code: "5252347183",
        recipient_signature: "Robert \u015awi\u015b",
        check_duplicate_number: true,
        bank_name: "mBank S.A.",
        bank_account: "78 1140 2004 0000 3402 4498 6037",
        invoice_date_kind: "service_date"
      )
    end

    it 'builds notes from order metadata' do
      expect(attrs[:notes]).to include("numer zam\u00f3wienia szukio: 17628")
      expect(attrs[:notes]).to include("url zam\u00f3wienia: http://szukio.pl/weryfikacja/17628/b4k")
      expect(attrs[:notes]).to include("termin p\u0142atno\u015bci: 21 dni od daty otrzymania faktury")
    end

    it 'builds service with pre-computed values' do
      expect(attrs[:services]).to eq([
        {
          name: "SzuKIO.pl - dost\u0119p 1 rok - limit 500 ods\u0142on dokument\u00f3w - 1 u\u017cytkownik",
          tax_symbol: 23,
          unit: "szt.",
          quantity: 1,
          unit_net_price: 142800,
          net_price: 142800,
          gross_price: 175644,
          tax_price: 32844
        }
      ])
    end
  end
end

RSpec.describe Infakt::KsefInvoiceData do
  let(:raw_data) do
    JSON.parse(
      File.read("data/invoices/2026/04/3950.2026.json"),
      symbolize_names: true
    )
  end

  subject { described_class.new(raw_data) }

  describe '#attributes' do
    let(:attrs) { subject.attributes }

    it 'builds full infakt payload' do
      expect(attrs).to include(
        number: "3950/2026",
        currency: "PLN",
        kind: "vat",
        payment_method: "transfer",
        invoice_date: "2026-04-08",
        sale_date: "2026-04-08",
        payment_date: "2026-04-08",
        paid_date: nil,
        net_price: 285600,
        tax_price: 65688,
        gross_price: 351288,
        left_to_pay: 351288,
        client_company_name: "GMINA CZERNICA",
        client_street: "ul. Kolejowa 3",
        client_street_number: "",
        client_flat_number: "",
        client_country: "PL",
        client_city: "Czernica",
        client_post_code: "55-003",
        client_tax_code: "9121101093",
        recipient_signature: "Irmina Janu\u015b",
        check_duplicate_number: true,
        bank_name: "mBank S.A.",
        bank_account: "78 1140 2004 0000 3402 4498 6037",
        invoice_date_kind: "service_date"
      )
    end

    it 'has no seller_signature' do
      expect(attrs).not_to have_key(:seller_signature)
    end

    it 'has no notes' do
      expect(attrs).not_to have_key(:notes)
    end

    it 'computes service values from net_price, quantity and vat_rate' do
      expect(attrs[:services]).to eq([
        {
          name: "SzuKIO.pl - dost\u0119p 1 rok - limit 1000 ods\u0142on dokument\u00f3w - 2 u\u017cytkownik\u00f3w",
          tax_symbol: 23,
          unit: "szt.",
          quantity: 1,
          unit_net_price: 285600,
          net_price: 285600,
          gross_price: 351288,
          tax_price: 65688
        }
      ])
    end
  end
end
