# PropertyDate
class PropertyDate < Property

  validate :mysql_date_compliance

  # Attribute Write value
  # :date
  # zulässig: Date, DateTime, Time, "yyyy-mm-dd" (+ Derivate), siehe Date.parse
  def value=(value)
    if (value.is_a? Date) || (value.is_a? Time) then
      pvalue = value
    else
      begin
        pvalue = Date.parse(value)
      rescue
        pvalue = nil
      end
    end
    self.data_date = pvalue
  end

  # Attribute Read value
  # :date
  def value
    if(data_date.is_a? Date)
      data_date
    else
      nil
    end
  end

  # (see Property#property_type)
  def property_type
    :date
  end
  
  # Validate for mysql date compliance. The supported range is '1000-01-01 00:00:00' to '9999-12-31 23:59:59'.
  # see https://dev.mysql.com/doc/refman/5.6/en/datetime.html
  def mysql_date_compliance
    mysql_min = Date.new(1000,01,01)
    mysql_max = Date.new(9999,12,31)
    if value.is_a?(Date) && (value < mysql_min || value > mysql_max)
      errors.add(:base, "Das Datum liegt außerhalb des erlaubten Intervalls.")
    end
  end
end
