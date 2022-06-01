# Die Aufgabe dieses Controllers ist es, das HTML der Edit-Modals bereitzustellen.
class EditController < ApplicationController
  before_action :authenticate_user!

  # @action GET
  # @url /new
  def new_modal
    # @glass = Glass.new(self) -> kann weg

    @alphabetical, @hierarchical = Ontology.creatable_types current_user

    render "glass/new_modal", layout: false
  end

  # @action GET
  # @url /edit
  def edit_modal
    @predicate = params[:predicate]
    @individual = Individual.find(params[:individual_id])
    @glass = Glass.new(self)

    # Für Curatorship
    range = @individual.range_of(@predicate)
    if range.is_a?(String)
      begin
        klass = range.constantize
        raise ErrorController::Forbidden unless klass <= Individual
        obj = klass.new
        if obj.weak?
          @weak_range = true
          @range_predicate = obj
            .predicates
            .select { |_, options| options[:fill_on_create] }
            .map    { |predicate, _| predicate }
            .reject { |predicate| predicate == @individual.inverse_of(@predicate) }
            .first
        end
      rescue
        # TODO Notification
      end
    end

    render "glass/edit_modal", layout: false
  end

  # @action GET
  # @url /edit/range
  def range
    
    predicate = params[:predicate]
    type = params[:type]
    individual_id = params[:individual_id]
    if individual_id
      individual = Individual.find(individual_id)
    elsif type
      klass = type.constantize
      raise ErrorController::Forbidden unless klass <= Individual
      individual = klass.new
    else
      # Here be dragons.
    end

    @glass = Glass.new(self)

    render html: @glass.new(individual, predicate)
  end

  # @action GET
  # @url /edit/property
  def property
    id = params[:id]
    prop = Property.find(id)

    @glass = Glass.new(self)

    render html: @glass.edit_property(prop)
  end

  # @action GET
  # @url /edit/weak_individual_form
  #
  # Get the form for new weak individuals like {WebResource} and {Address}.
  #
  # @arg type [String] The new weak individual's type.
  def weak_individual_form
    
    type = params[:type]
    klass = type.constantize
    raise ErrorController::Forbidden unless klass <= Individual

    @glass = Glass.new(self)

    render html: @glass.edit_individual(klass.new)
  end
end
