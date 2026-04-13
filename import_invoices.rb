#!/usr/bin/env ruby
require 'bigdecimal'
require 'dotenv'
require_relative 'lib/infakt'
require 'pp'

Dotenv.load

statuses = {}
gross = 0
flat_gross = 0.0
net = BigDecimal("0.0")
count = 0
# "data/invoices/2019/01/1144.2019.json" ,20,21,22,23}
Dir.glob("data/invoices/2019/11/*.json").each do |path|
  data = JSON.parse(File.read(path), symbolize_names: true)
  if path.include?("KOR")
    if data[:changed_fields]
      #puts "KOREKTA #{path}"
      puts "====="
      puts "#{data[:number]} #{data[:changed_fields]}"
      next
    end
    # next
    attrs = Infakt::CorrectiveInvoiceData.new(data).attributes
    result = Infakt::CorrectiveInvoice.create attrs
    # puts result
  else
    invoices = Infakt::Invoice.find(data[:number])
    attrs = Infakt::InvoiceData.new(data).attributes

    if invoices.any?
      invoice = invoices.first

      if invoice['status'] == 'draft'
        puts "Print #{data[:number]}"
        result = Infakt::Invoice.print(invoices.first)
      end

      if attrs[:vat_exemption_reason] && !invoice['vat_exemption_reason']
        puts "SKIP UPDATE"
        next
        # puts "Update VAT #{data[:number]}"
        # puts JSON.pretty_generate attrs
        result = Infakt::Invoice.update invoice, attrs
        # puts result.inspect
        #gets
        # puts path

        puts "Updated VAT EXEMPTION #{data[:number]} #{result['error'].inspect}"
      elsif attrs[:local_government_recipient_address]
        puts "SKIP UPDATE local_gov"
        next
        # puts "ADDR: #{attrs[:local_government_recipient_address][:street]}"
        # puts path
        print "Update Odbiorca #{data[:number]}"
        # puts JSON.pretty_generate attrs
        result = Infakt::Invoice.update invoice, attrs
        # puts result.inspect
        puts "Updated ERROR: #{result['error'].inspect}"
      end

      next #(puts("FOUND #{data[:number]} #{invoices.size}"))
    end

    if BigDecimal(attrs[:gross_price].to_s).to_s != (BigDecimal(data[:gross_value].to_s) * 100).to_s
    else
      puts "#{BigDecimal(attrs[:gross_price].to_s).to_s} #{(BigDecimal(data[:gross_value].to_s) * 100).to_s}"
      puts "#{attrs[:gross_price]} #{data[:gross_value]}"
      puts "#{attrs[:net_price]} #{data[:net_value]}"
    end

    # next

    result = Infakt::Invoice.create attrs
    puts "VAT: #{result['vat_exemption_reason'].inspect}" if result['vat_exemption_reason']
    puts "SERVICES: #{result['services'].inspect}" if result['vat_exemption_reason']
    puts "LOCAL: #{result['local_government_recipient_address'].inspect}" if result['local_government_recipient_address']

    if result["errors"]
      if result["errors"]["duplicated_number"]
        puts("DUP " + path)
      else
        puts "#{result["errors"]} #{path}"
      end
    else
      print "#{result["number"]} #{result["invoice_date"]} #{path}"
      puts " PRINTING #{result["number"]}"
      Infakt::Invoice.print(result)
    end
  end
end
