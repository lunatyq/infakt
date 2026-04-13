#!/usr/bin/env ruby
require 'csv'
require 'bigdecimal'
require 'attr_extras'

summary = true

if summary
  puts "Okres;Przychody SzuKIO IP;Przychody Pozostałe;Udział Przychodów IP w całości"
end

other = CSV.parse(File.read("data/invoices/taurus.csv"), :headers => true).map { |row| row.to_hash.each_with_object({}) { |(key, value), memo| if key == "net_value"; value=value.gsub(/[^\d,]/, '').sub(/,(\d{2})\Z/, '.\1');value = BigDecimal(value);end; memo[key.intern] = value} };

class OrderMock
  vattr_initialize [:invoice_date, :net_value, :invoice_number, :name, :gtu, :service_name]

  def service_supply_date
    invoice_date
  end

  def invoice_date
    Date.parse(@invoice_date)
  end

  def duration
  end

  def id
  end
end

others = other.map { |o| OrderMock.new(o) };
commercial_orders = Order.commercial.where(:service_supply_date => Date.new(2019,1,1)..Date.today);
(others + commercial_orders).group_by do |o|
  "#{o.service_supply_date.year}/#{'%02d' % o.service_supply_date.month}"
end.sort_by(&:first).each do |period, orders|
  unless summary
    puts "Okres:;#{period};#{orders.size};#{('%0.2f' % orders.map(&:net_value).reduce(:+)).sub('.',',')}"
  end

  totals = Hash.new { |k,h| k[h] = BigDecimal.new("0") }
  list = orders.sort_by { |o| [o.service_supply_date, o.invoice_number] }.map do |o|
    category = o.duration.to_i > 0 ? 'SzuKIO IP' : 'pozostałe'
    totals[category] += o.net_value

    elements = [
      ('%0.2f' % o.net_value).sub('.',','),
      category,
      o.id,
      o.invoice_number,
      o.invoice_date,
      o.service_supply_date,
      o.service_name,
      # o.name,
      # o.duration
    ].join(";")
  end

  ratio = totals["SzuKIO IP"] / totals.values.reduce(:+)


  unless summary
    list.unshift("wartość;kategoria;numer zamówienia;numer FV;data FV;data sprzedaży;opis")
    puts("Przychody SzuKIO IP;#{('%0.2f' % totals["SzuKIO IP"]).sub('.', ',')};Udział SzuKIO IP w całości;#{'%0.2f' % ratio}");
    puts("Przychody pozostałe;#{('%0.2f' % totals["pozostałe"]).sub('.', ',')}")
    puts list
    puts(";;;;")
  else
    puts "#{period};#{('%0.2f' % totals["SzuKIO IP"]).sub('.', ',')};#{('%0.2f' % totals["pozostałe"]).sub('.', ',')};#{('%0.2f' % ratio).sub('.', ',')}"
  end
end;1
