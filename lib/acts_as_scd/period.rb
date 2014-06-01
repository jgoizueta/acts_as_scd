module ActsAsScd

  class Period

    class DateValue
      def initialize(d)

        d = d.strftime('%Y%m%d') if d.respond_to?(:strftime)
        if String===d && d =~ /\A(\d\d\d\d)-(\d\d)-(\d\d)\Z/
          d = $1.to_i*10000 + $2.to_i*100 + $3.to_i
        end
        @value = d && d.to_i
      end

      attr_reader :value

      def to_date
        begin
          Date.new *parse
        rescue
          raise parse.inspect
        end
      end

      def parse
        y = @value/10000
        v = @value%10000
        m = v/100
        d = v%100
        [y,m,d]
      end

      def to_s
        if @value==START_OF_TIME
          ''
        elsif @value==END_OF_TIME
          ''
        else
          y,m,d = parse
          I18n.l Date.new(y, m, d)
        end
      end

      include ModalSupport::BracketConstructor
    end

    def self.date(date)
      DateValue[date].value
    end

    def self.date_to_s(date)
      DateValue[date].to_s
    end

    attr_reader :start, :end
    def from
      @start
    end
    def to
      @end
    end

    def initialize(from, to)
      @start = Period.date(from || START_OF_TIME)
      @end = Period.date(to || END_OF_TIME)
    end

    include ModalSupport::StateEquivalent

    def includes?(date)
      date = Period.date(date)
      @start <= date && date < @end
    end

    include ModalSupport::BracketConstructor

    def to_s(options={})
      if @start<=START_OF_TIME
        if @end>=END_OF_TIME
          options[:always] || I18n.t(:"scd.period.always") || '-'
        else
          "#{options[:until] || I18n.t(:"scd.period.until") || 'to'} #{Period.date_to_s(@end)}"
        end
      else
        if @end>=END_OF_TIME
          "#{options[:since] || I18n.t(:"scd.period.from") || 'since'} #{Period.date_to_s(@start)}"
        else
          [Period.date_to_s(@start), options[:between] ||  I18n.t(:"scd.period.between") || '-', Period.date_to_s(@end)].compact*' '
        end
      end
    end

    def valid?
      @start < @end
    end

    def empty?
      @start >= @end
    end

    def past_limited?
      @start > START_OF_TIME
    end

    def future_limited?
      @end < END_OF_TIME
    end

    def limited?
      past_limited? || future_limited?
    end

    def initial?
      @start == START_OF_TIME
    end

    def current?
      @end == END_OF_TIME
    end

    def reference_date
      if @start <= START_OF_TIME
        if @end >= END_OF_TIME
          DateValue[Date.today].value
        else
          DateValue[DateValue[@end].to_date - 1].value
        end
      else
        @start
      end
    end

  end

end
