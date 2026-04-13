#!/usr/bin/env ruby

require 'roo'
require 'roo-xls'
require 'json'

MAPS = {
  ["Data", "Nr dowodu księg.", "Konto", "NIP", "Netto", "VAT", "Brutto", "Nieuregulowane", "Nazwa kontrahenta", "Adres", "Opis zdarzenia", "Uwagi", "Pojazd"] => {
    "Nieuregulowane" => :ignore,
    "Data" => :operation_date,
    "Nr dowodu księg." => :document_number,
    "NIP" => :vat_id,
    "Netto" => :net_value,
    "VAT" => :vat,
    "Brutto" => :gross_value,
    "Nazwa kontrahenta" => :name,
    "Adres" => :address,
    "Opis zdarzenia" => :description,
    "Uwagi" => :notes,
    "Pojazd" => :vehicle,
    "Konto" => :account_number
  },
  ["Lp", "Data księgowania", "Data operacji", "Numer dokumentu", "Kontrahent", "Przychód", "Rozchód", "Kol.", "Opis", "Kategoria", "Opis kosztów", "Wynik", "Stan"] => {
    "Data operacji" => :operation_date,
    "Numer dokumentu" => :document_number,
    "Kontrahent" => :name,
    "Rozchód" => :expenditure,
    "Kol." => :account_column,
    "Opis" => :description,
    "Kategoria" => :category,
    "Opis kosztów" => :notes,
    "Lp" => :ignore,
    "Data księgowania" => :ignore,
    "Przychód" => :ignore,
    "Wynik" => :result,
    "Stan" => :state
  }
}
raw_data = []


# ["Data", "Nr dowodu księg.", "Konto", "NIP", "Netto", "VAT", "Brutto", "Nieuregulowane", "Nazwa kontrahenta", "Adres", "Opis zdarzenia", "Uwagi", "Pojazd"]
# ["Lp", "Data księgowania", "Data operacji", "Numer dokumentu", "Kontrahent", "Przychód", "Rozchód", "Kol.", "Opis", "Kategoria", "Opis kosztów", "Wynik", "Stan"]

id = 0

Dir.glob("data/koszty/*.xlsx").sort.each do |path|
  # puts path
  period = File.basename(path, ".xlsx")
  # puts period

  file = Roo::Spreadsheet.open(path)
  sheet = []

  index = 0
  header = nil
  file.sheet(0).each do |row|
    index += 1
    cells = row

    # puts row.join("\t")

    if !header && row.all? { |row| row.class == String }
      header = cells
      next
    end

    if header
      if cells.first.to_s.strip == "Razem" && cells.compact.size == 5
        next
      end

      map = MAPS[header] || raise("header missing #{header}")

      sheet << header.each_with_index.each_with_object({ :period => period }) do |(key, index), memo|
        value = cells[index]
        symbol = map[key] || raise("Unknown key #{key}=#{value}, #{cells.inspect}")
        next if symbol == :ignore

        memo[symbol] = case value
        when Float
          (BigDecimal('%5.2f' % value) * 100).round.to_i
        when Date
          value.to_s
        else
          value
        end
      end
    else
      one = cells.compact.size == 1
      is_known = cells.to_s.match(/Wyciąg z księgi|LSLABS/)

      if (one && is_known) || cells.compact.empty?
        next
      else
        puts "#{path} SKIP #{row.inspect}"
      end
    end
  end

  # puts "#{path}"
  # puts sheet.first.inspect
  # puts sheet.last.inspect
  raw_data << sheet
end

raw_data.flatten.each do |row|
  if row[:expenditure] == nil
    vehicle = row[:vehicle]

    if !vehicle.to_s.empty? && !row[:vat].to_s.empty?
      case vehicle
      when "75%, 50%"
        half_vat = BigDecimal("0.5") * row[:vat]
        accounted_net = (half_vat + row[:net_value]) * BigDecimal("0.75")

        row[:calculated_expenditure] = accounted_net.round.to_i
      when "75%, -"
        accounted_net = row[:net_value] * BigDecimal("0.75")
        row[:calculated_expenditure] = accounted_net.round.to_i
      when "100%, -"
        row[:calculated_expenditure] = row[:net_value]
      when "100%, 50%"
        accounted_net = row[:net_value] + (BigDecimal("0.5") * row[:vat]).round.to_i
        row[:calculated_expenditure] = accounted_net
      else
        raise "Vehicle not understood #{vehicle}"
      end
    else
      row[:calculated_expenditure] = row[:net_value]
    end
  else
    row[:calculated_expenditure] = row[:expenditure]
  end

  row[:id] = id += 1
end

File.open("data/koszty/2019-2023.json", "w") { |f| f.syswrite raw_data.flatten.to_json }

TITLES = {
  operation_date: 'Data',
  document_number: 'Nr Dowodu',
  calculated_expenditure: 'Koszt',
  direct_ip: 'Koszty bezpośrednie',
  shared_ip: 'IP',
  shared_other: 'Pozostałe',
  non_ip:	'Poza IP',
  name: 'Nazwa kontrahenta',
  description: 'Opis zdarzenia',
  vehicle: 'Pojazd',
  net_value: 'Netto',
  vat: 'Vat',
  gross_value: 'Brutto',
  id: 'Id'
}
order = %i(
  operation_date	document_number	calculated_expenditure
  direct_ip shared_ip shared_other non_ip
  name description vehicle net_value vat gross_value
  id
)

keys = order # .sort_by! { |k| order.index(k.to_s) }

csv_config = {
  col_sep: ";",
  row_sep: "\n",
  encoding: Encoding::UTF_8,
  # headers: keys,
  # write_headers: true
}

def format_numbers!(row, *keys)
  keys.each do |key|
    format_number!(row, key)
  end
end

def format_number!(row, name)
  row[name] = format_number(row[name])
end

def format_number(original_value)
  return unless original_value

  value = BigDecimal(original_value) / 100.0
  ('%.2f' % value).sub('.', ',')
end

csv_string = CSV.generate(**csv_config) do |csv|

  csv << TITLES.values_at(*order)
  # sort_by { |d| [d[:name].to_s.downcase, d[:description].to_s.downcase] }.each
  total = Hash.new(BigDecimal("0"))
  prev_period = nil
  raw_data.flatten.each do |row|
    total[row[:period]] += row[:calculated_expenditure]

    format_numbers!(row, :calculated_expenditure, :net_value, :gross_value, :vat)

    if prev_period && row[:period] != prev_period
      summary = {
        operation_date: prev_period,
        calculated_expenditure: format_number(total[prev_period])
      }
      csv << summary.values_at(*keys)
    end
    csv << row.values_at(*keys)

    prev_period = row[:period]
  end

  summary = {
    operation_date: prev_period,
    calculated_expenditure: format_number(total[prev_period])
  }
  csv << summary.values_at(*keys)
end

File.open("data/koszty/2019-2023.csv", "w") do |f|
  f.syswrite csv_string
end


# FV/4277/11/2021 / 30-11-2021 / Perski Media SeoHost.pl
