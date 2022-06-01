# Property
class Property < ApplicationRecord

  belongs_to :subject, inverse_of: :properties, class_name: "Individual"

  validate :do_validations

  # Callbacks
  before_save :before_save_actions
  after_save :after_save_actions
  after_destroy :after_destroy_actions

  # Attribute Write value
  # :string (Default)
  # Für :string-Properties jedoch Klasse PropertyString wählen!
  def value=(value)
    self.data = value.to_s.strip
  end

  # Attribute Read value
  # :string
  def value
    data
  end

  # Attribute Read value for Sort
  def sort_value
    value
  end

  def index_value
    value
  end

  # @return [Symbol] The property's type.
  def property_type
    :undefined
  end

  # @return [1, nil] The cardinality.
  def cardinality
    # kann nil sein
    subject.predicates[predicate][:cardinality]
  end

  # @return [Boolean]
  def cached?
    subject.predicates[predicate][:cached]
  end

  # @return [String, Array<String>]
  def range
    subject.predicates[predicate][:range]
  end

  # @return [Array] The possible values.
  def options
    subject.predicates[predicate][:options]
  end
  
  def map_zoomlevel
    subject.predicates[predicate][:map_zoomlevel]
  end

  # The inverse property.
  #
  # @note Wird in PropertyObjekt überschrieben
  def inverse
    nil
  end

  # @return [Boolean] Whether the property is an objekt property.
  def objekt?
    property_type == :objekt
  end

  # @return The default_value for this Property, if a default value for this
  #   Property is set in its owner Individual, nil otherwise.
  def default_value
    begin
      self.subject.predicates[self.predicate][:default]
    rescue
      nil
    end
  end
  
  # @return [String] the facet to be used as facetlink in glass
  def facetlink
    if facetlink = subject.predicates[predicate][:facet_link]
      indexfacets = subject.class.indexmapping[:facet]
      if indexfacets.keys.include?(facetlink.to_sym)
        return facetlink
      end
    end
  end
  
  
  def dereference
    subject.predicates[predicate][:dereference]
  end

  private

  # Does the property validations that are registered for the predicate.
  #
  # A "propperty validation" in this sense is a public methods of the individual instance that
  # takes a property as an argument. Its return value is ignored. It will check if the property
  # (possibly in combination with other existing properties of the individual) has some problems
  # (like having a badly formatted value, or introducing a cyclic hierarchy). In that case, it
  # should add an error to the property, like so:
  #
  #     def some_validation property
  #       if there_are_problems
  #         property.errors.add(:base, "There is a problem.")
  #       end
  #     end
  #
  # This is how property validations can be registered:
  #
  #     property "something", :string, validate: :some_validation
  def do_validations
    # Could also allow an array of methods here.
    if method = subject.predicates[predicate][:validate]
      subject.send(method, self)
    end
  end

  def before_save_actions
    # If this property is supposed to be cached, do so.
    if cached?
      # Just update the column without any callbacks or validations, because they are unnecessary,
      # because the PropertyManager will save the individual if this is necessary for callbacks
      # like set_labels. Any validations should react to creating the property in the first place,
      # i.e. they should already have happened once we are concerned about caching the field.
      subject.update_column("#{predicate}_cache", value)
    end
    if method = subject.predicates[predicate][:before_save]
      subject.send(method, self)
    end
  end
  
  def after_save_actions
    if method = subject.predicates[predicate][:after_save]
      subject.send(method, self)
    end
  end

  def after_destroy_actions
    # If this property was cached, we need to empty the cache on destroying the property.
    if cached?
      # Using `update_column` for the same reasons as described in before_save_actions.
      subject.update_column("#{predicate}_cache", nil)
    end
    if method = subject.predicates[predicate][:after_destroy]
      subject.send(method, self)
    end
  end
end
