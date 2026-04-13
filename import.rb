#!/usr/bin/env ruby
require 'bigdecimal'
require 'dotenv'
require_relative 'lib/infakt'
require 'pp'
require 'date'

require "openssl"
s = OpenSSL::X509::Store.new.tap(&:set_default_paths)
OpenSSL::SSL::SSLContext.send(:remove_const, :DEFAULT_CERT_STORE) rescue nil
OpenSSL::SSL::SSLContext.const_set(:DEFAULT_CERT_STORE, s.freeze)

Dotenv.load

`rsync -avz mt@harper:/srv/production/szukio-app/storage/szukio/shared/data/invoices data`
statuses = {}
gross = 0
flat_gross = 0.0
net = BigDecimal("0.0")
count = 0

# "data/invoices/2019/01/1144.2019.json" ,20,21,22,23}

def date_to_month_dir(date)
  "#{date.year}/#{'%02d' % date.month}"
end

files = [Date.today, Date.today-31].map do |date|
  dir = "data/invoices/#{date_to_month_dir(date)}/*.json"
  puts "Processing dir #{dir}"
  Dir.glob(dir)
end.flatten

files.each do |path|
  data = JSON.parse(File.read(path), symbolize_names: true)

  # next if (data[:issue_date] || data[:date]) < "2023-11-01"
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
        puts result.inspect
      else
        puts "OK #{data[:number]} #{data[:issue_date]}"
      end
    else
      result = Infakt::Invoice.create attrs
      
      if result["errors"]
        if result["errors"]["duplicated_number"]
          puts("DUP " + path)
        else
          puts "#{result["errors"]} #{path}"
        end
      elsif result['error']
         puts "ERROR: #{result['error']}"
      else
        print "CREATED #{result["number"]} #{result["invoice_date"]} #{path}"
        puts " PRINTING #{result["number"]}"
        Infakt::Invoice.print(result)
      end
    end
  end
end
