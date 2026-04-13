class Infakt
  class Base
    vattr_initialize :data

    def self.attr(*names)
      names.each do |name|
        define_method(name) do
          data[name.to_s]
        end
      end
    end

    def rational_to_text(rational)
      ('%0.2f' % rational).sub('.', ',')
    end

    def price_to_rational(price)
      BigDecimal(price) / 100.0
    end
  end
end
