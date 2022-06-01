# Data Model: Activity
class TimeSpan < Individual
  property "begin", :date, cardinality: 1, affects_label: true, validate: :begin_before_end
  property "end", :date, cardinality: 1, affects_label: true, validate: :end_after_begin
  property "display_as_year", :bool, cardinality: 1, default: false, affects_label: true
  property "time_span_label", :string, cardinality: 1
  property "is_time_span_of", :objekt, range: "Event", inverse: "ocurred_at", cardinality: 1, is_owner: true

  # (see Individual.weak?)
  # @note Man könnte sich auch TimeSpans vorstellen, für die es keine Duplikate geben soll,
  #   und die daher nicht weak sein sollten, so wie "19. Jahrhundert". Zur Zeit sind aber
  #   die meisten TimeSpans von der Form "Startdatum - Enddatum", und die sind offenbar weak.
  #   Deshalb setze hier diese Klasse zunächst auf "weak".
  def self.weak?
    true
  end

  # Validate begin date.
  def begin_before_end begin_prop
    if begin_prop.value.is_a?(Date) && end_value.is_a?(Date) && begin_prop.value > end_value
      begin_prop.errors.add(:base, "Das Startdatum darf nicht hinter dem Enddatum liegen.")
    end
  end

  # Validate end date.
  def end_after_begin end_prop
    if begin_value.is_a?(Date) && end_prop.value.is_a?(Date) && begin_value > end_prop.value
      end_prop.errors.add(:base, "Das Enddatum darf nicht vor dem Startdatum liegen.")
    end
  end

  # @return [Boolean] Whether the time span is still ongoing.
  def current?
    (begin_value.nil? || begin_value < Time.now) &&
      (end_value.nil? || end_value > Time.now)
  end

  private

  def set_labels
    self.label = time_span_label_value

    # If time_span_label was empty or not set, generate a label from date values.
    if self.label.nil? || self.label.size == 0
      date_format = display_as_year_value ? "%Y" : "%-d.%-m.%Y"

      begin_str = begin_value ? begin_value.strftime(date_format) : nil
      end_str   = end_value   ? end_value.strftime(date_format)   : nil

      self.label = if begin_str && end_str
        begin_str == end_str ? begin_str : "#{begin_str} - #{end_str}"
      elsif begin_str
        "Seit #{begin_str}"
      elsif end_str
        "Bis #{end_str}"
      else
        ""
      end
    end

    self.inline_label = label
  end
end
