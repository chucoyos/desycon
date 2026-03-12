module CustomsAgents
  class BusinessHoursService
    class << self
      def add_weekday_hours(from_time:, hours:)
        current_time = from_time.in_time_zone
        remaining_hours = hours.to_i

        while remaining_hours.positive?
          current_time += 1.hour
          next if weekend?(current_time)

          remaining_hours -= 1
        end

        current_time
      end

      private

      def weekend?(time)
        time.saturday? || time.sunday?
      end
    end
  end
end
