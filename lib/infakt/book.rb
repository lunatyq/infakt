class Infakt
  class Book < Base
    URL = "https://api.infakt.pl/api/v3/books.json"
    ENTITY_URL = "https://api.infakt.pl/v3/books/{{book_id}}.json"

    class Line < Base
      # {"ordinal"=>168, "date"=>"2024-04-01", "number"=>"1500/DED/04/2024", "client_name"=>"IQ PL Sp. z o.o.", "client_address"=>"ul. Geodetów 16\n80-298 Gdańsk", "description"=>"Wydatki przedsiębiorcy", "income_cargo_services"=>0, "income_others"=>0, "income_summary"=>0, "expense_cargo_material"=>0, "expense_incidental"=>0, "expense_salary"=>0, "expense_others"=>56000, "expense_sum"=>56000, "expense_research"=>

      attr :ordinal, :date, :number, :client_name, :client_address, :description
      attr :income_summary, :expense_sum
      attr :income_others
      attr :expense_incidental
      attr :expense_salary
      attr :expense_others
      attr :expense_research
      attr :expense_cargo_material, :income_cargo_services

      TITLES = [:date, :number, :expense_sum_text, :client_name, :description]

      def titles
        TITLES
      end

      def expense_sum_rational
        price_to_rational(expense_sum)
      end

      def expense_sum_text
        rational_to_text(expense_sum_rational)
      end

      def to_h
        titles.each_with_object({}) do |title, memo|
          memo[title] = field_value(title)
        end
      end

      def field_value(title)
        send(title)&.gsub(/[\r\n]+/, ' ')
      end

      def dump_data
        titles.map do |title|
          field_value(title)
        end
      end
    end

    class Transfered
      vattr_initialize :data
    end

    def to_s
      "<#{self.class} #{id} #{period} #{transfered.inspect} #{lines.inspect}>"
    end

    def id
      data['id']
    end

    def period
      data['period']
    end

    def expenses_price
      data['expenses_price']
    end

    def transfered
      details['transfered']
    end

    def lines
      details['lines'].map do |line|
        Line.new(line)
      end
    end

    def expenses_rational
      price_to_rational(expenses_price)
    end

    def expenses_text
      rational_to_text(expenses_rational)
    end

    def total_expense_sum_rational
      lines.map(&:expense_sum_rational).reduce(:+) || BigDecimal.new(0.0)
    end

    def expense_sum_text
      rational_to_text(total_expense_sum_rational)
    end

    def details
      @details ||= get_details
    end

    def get_details
      Request.new(entity_url).get
    end

    def entity_url
      ENTITY_URL.sub("{{book_id}}", id.to_s)
    end

    def self.url
      URL
    end

    def self.list
      raw_results = Request.new(URL).get

      results = new_from_raw_results(raw_results)

      while results.size < raw_results['metainfo']['total_count']
        next_url = raw_results['metainfo']['next']
        puts next_url
        raw_results = Request.new(next_url).get
        results += new_from_raw_results(raw_results)
      end

      results
    end

    def self.new_from_raw_results(raw_results)
      raw_results['entities'].map do |raw_book|
        new(raw_book)
      end
    end
  end
end
