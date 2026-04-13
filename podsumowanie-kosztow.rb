#!/usr/bin/env ruby

require 'roo'
require 'roo-xls'

path = "koszty-2019-2023-adnotacje.xlsx"
file = Roo::Spreadsheet.open(path)

rows = file.sheet(0).to_a
header = rows.shift
header = rows.shift.map(&:intern)
#.map(&:intern)

data = rows.map do |row|
  header.each_with_index.each_with_object({}) do |(name, index), memo|
    memo[name] = row[index]
    if name == :"IP cost"
      memo[:ip_cost] = memo[name].sub('ó', 'o').downcase
      memo[:ip_cost] = "ogolne" if memo[:ip_cost] == "nieznane"
    end
  end
end

data.each do |row|
  if row[:vehicle] == "100%, 50%"
    # row[:net_value] + (BigDecimal("0.5") * row[:vat]).round.to_i
    row[:calculated_expenditure] = row[:net_value]
  end

  puts row.inspect unless row[:calculated_expenditure]
end

puts "Okres;Koszty SzuKIO;Koszty Ogólne;Koszty Pozostałe"
data.group_by { |d| d[:period] }.sort_by(&:first).each do |period, list|
  totals = Hash.new(0)
  list.group_by do |cost_line|
    cost_line[:ip_cost]
  end.map do |ip_cost, cost_lines|
    totals[ip_cost] = cost_lines.map { |cl| cl[:calculated_expenditure] }.reduce(:+) || 0
  end

  puts "#{period};#{totals['szukio'].to_s.sub(/(\d{2})\Z/, ',\1')};#{totals['ogolne'].to_s.sub(/(\d{2})\Z/, ',\1')};#{totals['inne'].to_s.sub(/(\d{2})\Z/, ',\1')}"
end
