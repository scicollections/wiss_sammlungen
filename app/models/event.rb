# Represents an event.
class Event < Individual
  property "ocurred_at", :objekt, range: "TimeSpan", inverse: "is_time_span_of", cardinality: 1

  access_rule action: [:create, :edit, :delete], minimum_required_role: :admin

  # @return [Boolean] Whether the event is ongoing.
  def current?
    ocurred_at_value && ocurred_at_value.current?
  end
end
