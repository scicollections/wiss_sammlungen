class IndividualController < ApplicationController
  before_action :set_individual

  # @action GET
  # @url /:individual/:id
  def show
    raise ErrorController::Forbidden unless current_user.can_view_individual?(@record)
    page_title @record.label

    # Second ID (fuer Darstellung des abhaengigen Objekts)
    @sec_id = params[:sec_id]

    # Last-search navigation
    session[:result_num] = params[:hit].to_i if params[:hit]
    @navigator = Navigator.new(session)

    # Highlight User Home Tab wenn der current_user seinen eigenen Datensatz anguckt
    if current_user.present? && current_user.person == @record
      @user_menu_tab_self_active = true
    end

    # Wird in UpdateController#create_individual auf "edit" gesetzt, damit man nach dem
    # Erstellen gleich in den Bearbeiten-Modus kommt.
    @mode = params[:mode] if params[:mode] && current_user.can_edit_individual?(@record)

    @glass = Glass.new(self)

    if request.xhr? && params[:expand]
      expand_predicate = params[:expand]
      editable = current_user.can_edit_property?(subject: @record, predicate: expand_predicate)

      render partial: "glass/inline/expanded_property_group",
        locals: {
          individual: @record,
          predicate: expand_predicate,
          editable: editable,
          hierarchical: (params[:sortmode] == "hierarchical")
        }
    else
      respond_to do |format|
        format.html {
          render "show"
        }
        format.json { 
          http_auth
          render json: @record.to_hash(current_user).to_json
        }
      end
    end
  end

  # @action GET
  # @url /relations/:individual_id
  #
  # @note Should be access via AJAX.
  def relations
    if current_user.public?
      raise ErrorController::Forbidden
    end

    @glass = Glass.new(self)

    render(
      "individual/_tab_relations",
      locals: { individual: @record },
      formats: [:html],
      layout: false
    )
  end

  SEARCH_TYPES =
  [ "ConceptScheme",
    "OrganisationType",
    "PlaceType",
    "ActivityType",
    "CollectionRole",
    "CollectionType",
    "Subject",
    "LivingBeing",
    "SciCollection",
    "Place",
    "Person",
    "Organisation",
    "CollectionActivity",
    "ObjectGenre"]

  # input query_string, remove special characters and split to tokens
  # then apply wildcard characters as pre- and suffix to perform sql-substring
  # search using like (resulting in SQL: SELECT ... label LIKE '%Peter%' ...)
  # resulting in an array in a form like "foo+#bar, bla.foo" => ["%foo%", "%bar%", "%bla%", "%foo%"]
  def tokenize query_string
    query_string.gsub(/\p{^L}/, " ").split.collect{ |s| "%" + s + "%" }
  end
  
  # provides async dereferenced data because retrieving deref data from
  # external resources may take some time.
  def dereferenced_data
    prop_id = params[:property_id]
    property = @record.properties.find prop_id
    if property and current_user.can_view_property?(property)
      render partial: "glass/inline/deref_data", locals: {deref_data: property.dereference(property.value), property: property}
    else
      render "Forbidden", status: 403, layout: "error"
    end
  end

  private

  def set_individual
    # Teste 500-er Error
    if params[:id] == "error500"
      raise MayaTestException
    end

    begin
      @record = Individual.find(params[:id].to_i) 
    rescue ActiveRecord::RecordNotFound
      raise ErrorController::Gone if Revision.where(subject_id: params[:id]).any?
      raise # otherwise reraise Exception
    end
  end
end

# A test exception to trigger 500: Internal Server Error
class MayaTestException < StandardError
end

