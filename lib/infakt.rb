require 'json'
require 'attr_extras'

require "uri"
require "net/http"

require_relative 'infakt/base'
require_relative 'infakt/request'

require_relative 'infakt/invoice'
require_relative 'infakt/corrective_invoice'

require_relative 'infakt/vat_rate'
require_relative 'infakt/vat_exemption_reason'
require_relative 'infakt/invoice_status'
require_relative 'infakt/book'

class Infakt
  module DataProcessing
    def build_service(raw_service)
      vat_rate = raw_service.fetch(:vat_rate)
      tax_symbol = if vat_rate == 0
        "zw"
      else
        vat_rate
      end
      {
        name: raw_service.fetch(:description),
        tax_symbol: tax_symbol,
        unit: raw_service.fetch(:unit_name),
        quantity: raw_service.fetch(:unit_count),
        unit_net_price: format_number(raw_service.fetch(:net_price)),
        net_price: format_number(raw_service.fetch(:net_value)),
        gross_price: format_number(raw_service.fetch(:gross_value)),
        tax_price: format_number(raw_service.fetch(:vat))
        # gtu_id
      }
    end

    def bill_to
      raw_data.fetch(:bill_to)
    end

    def issuer
      raw_data.fetch(:issuer)
    end

    def net_value
      format_number raw_data.fetch(:net_value)
    end

    def vat
      format_number raw_data.fetch(:vat)
    end

    def gross_value
      format_number raw_data.fetch(:gross_value)
    end

    def format_number(value)
      #(value * 100).to_i
      (BigDecimal(value.to_s) * 100).to_i
    end
  end

  class CorrectiveInvoiceData
    vattr_initialize :raw_data
    include DataProcessing

    def attributes
      {
        # confirmation
        currency: "PLN",
        ## [:services_after,
        ## :corrected_invoice_number,
        corrected_invoice_number: raw_data.fetch(:corrected_invoice_number),
        ## :corrected_invoice_issue_date,
        corrected_invoice_date: raw_data.fetch(:corrected_invoice_issue_date),
        ## :vat_summary_correction,
        ## :receiver_name,
        recipient_signature: bill_to.fetch(:contact_name),
        ## :issuer,
        seller_signature: issuer.fetch(:contact_name),
        ## :vat,
        tax_price: vat,
        ## :net_value,
        net_price: net_value,
        ## :gross_value,
        gross_price: gross_value,
        ## :vat_summary_before,
        ## :vat_summary_after,
        ## :services_correction,
        ## :number,
        number: raw_data.fetch(:number),
        ## :service_supply_date,
        sale_date: raw_data.fetch(:service_supply_date),
        ## :correction_reason,
        correction_reason: 'other',
        ## :date,
        invoice_date: raw_data.fetch(:date),
        ## :payment_deadline_text,
        ## :services_before]

        ## :bill_to,
        client_company_name: bill_to.fetch(:name),
        # client_business_activity_kind: 'other', opt
        client_street: bill_to.fetch(:street),
        client_street_number: "",
        client_flat_number: "",
        client_country: "PL",
        client_city: bill_to.fetch(:city),
        client_post_code: bill_to.fetch(:postcode),
        client_tax_code: bill_to.fetch(:vat_id),

        check_duplicate_number: true,
        bank_name: issuer.fetch(:bank_name),
        bank_account: issuer.fetch(:bank_account_number),
        invoice_date_kind: "service_date",
        services: services,
        notes: raw_data[:changed_fields]
      }
    end

    def services
      return [] unless raw_data[:services_before] || raw_data[:services_after]
      raw_data.fetch(:services_before).each_with_index.map do |raw_service, index|
        build_service(raw_service).merge(:correction => false, :group => index)
      end + raw_data.fetch(:services_after).each_with_index.map do |raw_service, index|
        build_service(raw_service).merge(:correction => true, :group => index)
      end
    end
  end

  class InvoiceData
    vattr_initialize :raw_data

    include DataProcessing
    # tax_free_regulation
    # ship_to
    # services
    #   [ {:unit_name=>"szt.", :net_price=>420.0, :description=>"SzuKIO.pl - dostęp 1 rok - limit 125 odsłon dokumentów - 1 użytkownik", :net_value=>420.0, :unit_count=>1, :vat_rate_name=>"23%", :vat_rate=>23, :gross_value=>516.6, :vat=>96.6, :symbol=>nil}
    # vat_summary
    # - [:net_value, 420.0]
    # - [:gross_value, 516.6]
    # - [:rate_summaries, [{:net_value=>420.0, :vat_rate_name=>"23%", :vat_rate=>23, :gross_value=>516.6, :vat=>96.6}]]
    # - [:vat, 96.6]
    # issuer
    # - [:email, "szukio@szukio.pl"]
    # - [:postcode, "42-274"]
    # - [:name, "LSLABS Maciej Tomaka"]
    # - [:phone, "34 343 50 28"]
    # - [:vat_id, "9271758535"]
    # - [:bank_name, "mBank S.A."]
    # - [:bank_account_number, "78 1140 2004 0000 3402 4498 6037"]
    # - [:city, "Aleksandria Pierwsza"]
    # - [:street, "ul. Rolnicza 41"]
    # - [:contact_name, "Maciej Tomaka"]
    # bill_to
    # - [:postcode, "78-200"]
    # - [:name, "Miasto Białogard Urząd Miasta Białogard"]
    # - [:vat_id, "6721001814"]
    # - [:street, "ul. 1 Maja 18"]
    # - [:contact_name, "Jarosław Chełminiak"]
    # - [:city, "Białogard"]

    def services
      # services
      #   [ {:unit_name=>"szt.", :net_price=>420.0, :description=>"SzuKIO.pl - dostęp 1 rok - limit 125 odsłon dokumentów - 1 użytkownik", :net_value=>420.0, :unit_count=>1, :vat_rate_name=>"23%", :vat_rate=>23, :gross_value=>516.6, :vat=>96.6, :symbol=>nil}
      raw_data.fetch(:services).map do |raw_service|
        build_service(raw_service)
      end
    end

    # def service_attributes
    #   %w(
    #   # name
    #   # tax_symbol
    #   unit
    #   quantity
    #   unit_net_price
    #   net_price
    #   gross_price
    #   tax_price
    #   gtu_id
    #   vat_date_value # sale_date
    #   )
    # end

    def notes
      # order_number
      # client_supplied_details
      # order_url
      # payment_deadline_text
      # order id
      [
        "numer zamówienia szukio: #{raw_data.fetch(:order_number)}",
        "url zamówienia: #{raw_data.fetch(:order_url)}",
        "termin płatności: #{raw_data.fetch(:payment_deadline_text)}",
        "dane od zamawiającego: #{raw_data.fetch(:client_supplied_details)}"
      ].join("\n")
    end

    def due_amount
      format_number raw_data.fetch(:due_amount)
    end

    def paid_on
      raw_data.fetch(:paid_on)
    end

    def attributes
      {
        ## number
        number: raw_data.fetch(:number),
        ## currency
        currency: raw_data.fetch(:currency),
        notes: notes,
        kind: 'vat',
        payment_method: 'transfer', # COMPENSATION?
        ## issuer:
        ## - [:email, "szukio@szukio.pl"]
        ## - [:postcode, "42-274"]
        ## - [:name, "LSLABS Maciej Tomaka"]
        ## - [:phone, "34 343 50 28"]
        ## - [:vat_id, "9271758535"]
        ## - [:bank_name, "mBank S.A."]
        ## - [:bank_account_number, "78 1140 2004 0000 3402 4498 6037"]
        ## - [:city, "Aleksandria Pierwsza"]
        ## - [:street, "ul. Rolnicza 41"]
        ## - [:contact_name, "Maciej Tomaka"]
        seller_signature: issuer.fetch(:contact_name),
        ## issue_date
        invoice_date: raw_data.fetch(:issue_date),
        ## service_supply_date
        sale_date: raw_data.fetch(:service_supply_date),
        # status: 'draft',
        ## paid_on
        ## fully_paid - UNUSED
        ## due_amount
        ## paid_amount

        payment_date: raw_data.fetch(:issue_date),
        paid_date: paid_on,
        ## net_value
        ## gross_value
        ## vat
        net_price: net_value,
        tax_price: vat,
        gross_price: gross_value,
        left_to_pay: due_amount,
        ## bill_to
        ## - [:postcode, "78-200"]
        ## - [:name, "Miasto Białogard Urząd Miasta Białogard"]
        ## - [:vat_id, "6721001814"]
        ## - [:street, "ul. 1 Maja 18"]
        ## - [:contact_name, "Jarosław Chełminiak"]
        ## - [:city, "Białogard"]
        client_company_name: bill_to.fetch(:name),
        # client_business_activity_kind: 'other', opt
        client_street: bill_to.fetch(:street),
        client_street_number: "",
        client_flat_number: "",
        client_country: "PL",
        client_city: bill_to.fetch(:city),
        client_post_code: bill_to.fetch(:postcode),
        client_tax_code: bill_to.fetch(:vat_id),
        recipient_signature: bill_to.fetch(:contact_name),
        check_duplicate_number: true,
        bank_name: issuer.fetch(:bank_name),
        bank_account: issuer.fetch(:bank_account_number),
        # sale_type: "service",
        invoice_date_kind: "service_date",
        services: services,
        # vat_exemption_reason: "ID podstawy zwolnienia z VAT (dostępne w sekcji "Podstawy zwolnień z VAT"
        # bdo_code
        # transaction_kind_id
        # document_markings_ids: []
        # "ship_to":{"street":"ul. Zwyci\u0119stwa 21","postcode":"44-100","city":"Gliwice","name":"Urz\u0105d Miejski w Gliwicach"
        # local_government_recipient_address: ship_to

        # local_government_seller_address zawierają następujące klucze:

        # Parametr	Typ danych	Wymagany	Opis
        # company_name	string	Tak	Nazwa JST
        # nip	string	Tak	NIP
        # street	string	Tak	Ulica
        # street_number	string	Tak	Numer budynku
        # flat_number	string	Tak	Numer lokalu
        # postal_code	string	Tak	Kod pocztowy
        # city	string	Tak	Miasto
        # country	string	Tak	Kod kraju, "PL" dla Polski
      }.merge(optionals)
    end

    def optionals
      {}.tap do |opts|
        opts[:local_government_recipient_address] = ship_to if ship_to
        opts[:vat_exemption_reason] = vat_exemption_reason if vat_exemption_reason
      end
    end

    def vat_exemption_reason
      if raw_data[:tax_free_regulation].to_s != ""
        3275
      end
    end

    def ship_to
      ship_to = raw_data[:ship_to]

      if ship_to
        {
          company_name: ship_to.fetch(:name),
          street: ship_to.fetch(:street),
          street_number: "-",
          postal_code: ship_to.fetch(:postcode),
          city: ship_to.fetch(:city),
          country: "PL"
        }
      end
    end
  end
end
