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

title_map = {
  date: 'Data',
  number: 'Nr Dowodu',
  expense_sum_text: 'Netto',
  client_name: 'Nazwa kontrahenta',
  description: 'Opis zdarzenia',
  direct: 'Koszty bezpośrednie',
  ip: 'IP',
  other: 'Pozostałe',
  non_ip: 'Poza IP'
}

titles = [
  :date, :number, :expense_sum_text,
  :direct, :ip, :other, :non_ip,
  :client_name, :description
]


books = Infakt::Book.list
year = "2025"
books = books.select { |book| book.period.split("-").first == year }
puts "#{year};#{'%5.2f' % books.map(&:total_expense_sum_rational).reduce(:+)}"
books.each do |book|
  next unless book.period.split("-").first == year
  puts "Okres;#{book.period};#{book.expense_sum_text};#{book.expenses_text}"
  puts [nil, nil, nil, nil, '"Koszty Wspólne"'].join(";")
  puts title_map.values_at(*titles).map { |w| %{"#{w}"} }.join(";")
  book.lines.each do |line|
    puts line.to_h.values_at(*titles).join(";") if line.expense_sum > 0
  end
end
