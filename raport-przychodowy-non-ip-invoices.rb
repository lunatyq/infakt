#!/usr/bin/env ruby
require 'csv'
require 'bigdecimal'
require 'attr_extras'
require 'json'
require 'fileutils'

summary = false

if summary
  puts "Okres;Przychody SzuKIO IP;Przychody Pozostałe;Udział Przychodów IP w całości"
end


class CorrectiveInvoice
  vattr_initialize :data, :path

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
  vattr_initialize :data, :path

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
      CorrectiveInvoice.new(data, path)
    else
      new(data, path)
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

invoices = Invoice.read.select do |invoice|
  invoice.service_supply_date >= Date.new(2019)
end

grand_total = BigDecimal("0")
invoices.each do |order|
  if order.ip?
    pdf_path = order.path.sub('.json', '.pdf')

    ssd = order.service_supply_date
    period = "#{ssd.year}-#{'%02d' % ssd.month}"
    destination_path = File.join("miesiacami-swiadczenia/#{ssd.year}/#{period}")
    FileUtils.mkdir_p(destination_path)

    if order.corrective_invoices.any?
      order.corrective_invoices.each do |inv|
        cor_pdf_path = inv.path.sub('.json', '.pdf')
        puts cor_pdf_path
        FileUtils.cp(cor_pdf_path, File.join(destination_path, File.basename(cor_pdf_path)))
      end
    end
    # puts "#{pdf_path} #{destination_path}"
    FileUtils.cp(pdf_path, File.join(destination_path, File.basename(pdf_path)))
  end
end
