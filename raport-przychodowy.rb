#!/usr/bin/env ruby
require 'csv'
require 'bigdecimal'
require 'attr_extras'
require 'json'

summary = false

if summary
  puts "Okres;Przychody SzuKIO IP;Przychody Pozostałe;Udział Przychodów IP w całości"
end


class CorrectiveInvoice
  vattr_initialize :data

  def corrected_invoice_number
    data.fetch(:corrected_invoice_number)
  end

  def invoice_number
    data.fetch(:number)
  end

  def corrective?
    true
  end

  def net_value
    BigDecimal(data.fetch(:net_value).to_s)
  end

  def service_supply_date
    Date.parse(data.fetch(:service_supply_date))
  end
end

class Invoice
  vattr_initialize :data

  def corrective_invoices
    @corrective_invoices ||= []
  end

  def service_supply_date
    @service_supply_date ||= Date.parse(data.fetch(:service_supply_date))
  end

  def invoice_number
    data.fetch(:number)
  end

  def ip?
    service_name.downcase.include?("dostęp") if service_name
  end

  def issue_date
    @issue_date ||= Date.parse(data.fetch(:issue_date))
  end

  def corrective?
    false
  end

  def net_correction
    corrective_invoices.map(&:net_value).reduce(:+) || 0
  end

  def net_value
    original_net_value + net_correction
  end

  def original_net_value
    BigDecimal(data.fetch(:net_value).to_s)
  end

  def service_name
    data[:services]&.first&.fetch(:description)
  end

  def self.read_json(path)
    data = JSON.parse(File.read(path), symbolize_names: true)
    if data[:correction_reason]
      CorrectiveInvoice.new(data)
    else
      new(data)
    end
  end

  def self.read
    all_invoices = Dir.glob("data/invoices/**/*.json").map do |path|
      Invoice.read_json path
    end

    all_invoices.reject! { |i| i.invoice_number == "2/KOR/11/2019" }

    correctives, invoices = all_invoices.partition(&:corrective?)

    by_number = invoices.each_with_object({}) do |invoice, memo|
      memo[invoice.invoice_number] = invoice
    end

    correctives.each do |corrective|
      by_number[corrective.corrected_invoice_number].corrective_invoices << corrective
    end

    invoices
  end
end

# puts invoices.size
# invoices.reject(&:ip?).each do |invoice|
#   puts "#{invoice.service_supply_date};#{invoice.ip?};#{invoice.description}"
# end

class ForeignInvoice
  vattr_initialize [:issue_date, :service_supply_date, :net_value, :invoice_number, :name, :gtu, :service_name]

  def service_supply_date
    invoice_date
  end

  def ip?
    false
  end

  def issue_date
    Date.parse(@issue_date)
  end

  def service_supply_date
    Date.parse(@service_supply_date)
  end

  def id
  end

  def self.read
    CSV.parse(File.read("data/foreign-invoices/taurus.csv"), :headers => true).map do |row|
      row.to_hash.each_with_object({}) do |(key, value), memo|
        if key == "net_value"
          value = value.gsub(/[^\d,]/, '').sub(/,(\d{2})\Z/, '.\1')
          value = BigDecimal(value)
        end

        memo[key.intern] = value
      end.tap do |final_row|
        final_row[:service_supply_date] = final_row[:invoice_date]
        final_row[:issue_date] = final_row.delete(:invoice_date)
      end
    end.map do |data|
      new(data)
    end
  end
end

foreign = [] # ForeignInvoice.read
invoices = Invoice.read.select do |invoice|
  invoice.service_supply_date.year == 2025
end

grand_total = BigDecimal("0")
(foreign + invoices).group_by do |o|
  "#{o.service_supply_date.year}/#{'%02d' % o.service_supply_date.month}"
end.sort_by(&:first).each do |period, orders|
  unless summary
    puts "Okres:;#{period};#{orders.size};#{('%0.2f' % orders.map(&:net_value).reduce(:+)).sub('.',',')}"
  end

  totals = Hash.new { |k,h| k[h] = BigDecimal("0") }
  list = orders.sort_by { |o| [o.service_supply_date, o.invoice_number] }.map do |o|
    category = o.ip? ? 'SzuKIO IP' : 'pozostałe'
    totals[category] += o.net_value

    grand_total += o.net_value if o.ip?
    elements = [
      ('%0.2f' % o.net_value).sub('.',','),
      category,
      o.invoice_number,
      o.issue_date,
      o.service_supply_date,
      o.service_name,
      # o.name,
      # o.duration
    ].join(";")
  end

  ratio = totals["SzuKIO IP"] / totals.values.reduce(:+)


  unless summary
    list.unshift("wartość;kategoria;numer FV;data FV;data sprzedaży;opis")
    puts("Przychody SzuKIO IP;#{('%0.2f' % totals["SzuKIO IP"]).sub('.', ',')};Udział SzuKIO IP w całości;#{'%0.2f' % ratio}");
    puts("Przychody pozostałe;#{('%0.2f' % totals["pozostałe"]).sub('.', ',')}")
    puts list
    puts(";;;;")
  else
    puts "#{period};#{('%0.2f' % totals["SzuKIO IP"]).sub('.', ',')};#{('%0.2f' % totals["pozostałe"]).sub('.', ',')};#{('%0.2f' % ratio).sub('.', ',')}"
  end
end;1
