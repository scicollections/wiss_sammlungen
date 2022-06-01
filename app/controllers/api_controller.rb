# Provide APIs like ISUS API and Fibonacci API.
#
class ApiController < ApplicationController

  # @action GET
  # @url /api/fibonacci/individual?id=[:id]
  # @arg id [Integer] The individual id.
  def fibonacci_individual
    doc = get_single_document(params[:id].to_i)
    if doc
      render json: result_to_json(doc), status: 200
    else
      head 404
    end
  end

  # @action GET
  # @url /api/fibonacci/search?q=[:query]
  # @arg q [String] The query.
  def fibonacci_search
    if params[:q].to_i.to_s == params[:q]
      doc = get_single_document(params[:q].to_i)
      results = doc ? [result_to_json(doc)] : []
    else
      search = Searcher.new
      conf = {
        query: params[:q],
        from: 0,
        size: 75,
        cat_filter: ["actor","activity","collection"],
        sort_by_relevance: true
      }
      search.configure conf
      search.execute
      results = []
      search.results.each do |r|
        results << result_to_json(r)
      end
    end

    jsn = {
      number_of_results: results.size,
      results: results
    }
    render json: jsn, status: 200
  end

  # @action GET
  # @url /api/fibonacci/outofthebox?q=[:term]`
  #
  # Render some HTML to be displayed as-is on the main web site. The content can be found at:
  #
  # - http://wissenschaftliche-sammlungen.de/de/service-material/informationsportale
  # - http://wissenschaftliche-sammlungen.de/de/netzwerk/sammlungsbeauftragte
  # - http://wissenschaftliche-sammlungen.de/de/foerdermoeglichkeiten
  #
  # @arg options Set this to "true" to get a list of possible `q` values.
  # @arg q ["portale", "sammlungskoordinationen", "foerderprogramme"] The kind of resource.
  def fibonacci_outofthebox
    if params[:options] == "true"
      # Return all possible parameters.
      render json: OOTB_PARAMETERS

    else
      term = params[:q]
      case term
      when "portale"
        # get all unis with collection portal and sort by the name of their location
        uni_list = Organisation
          .universities
          .select { |u| u.safe_value("collection_portal").present? }
          .select { |u| u.visibility == :public }
          .sort_by { |u| u.safe_value("location") }
        @portals = uni_list.collect do |uni|
          {
            name: uni.label,
            url: uni.collection_portal.value.url.value
          }
        end

      when "sammlungskoordinationen"
        @universities = collection_coordinations.collect do |el|
          coords = el[:coords].collect do |prop|
            coord = prop.value
            # collect all associated persons
            persons = coord.person
                .select {|prop| prop.value && prop.value.visibility == :public}
                .collect {|prop| {name: prop.value.label, id: prop.value.id} }
            unless coord.homepage.empty?
              homepage = coord.homepage.first.value.safe_value("url")
              homepage_name = coord.homepage.first.value.label
            end
            {
              id: coord.id,
              name: coord.label,
              homepage: homepage,
              homepage_name: homepage_name,
              address: (coord.safe_value "address"),
              email: (coord.safe_value "email"),
              phone: (coord.safe_value "phone"),
              persons: persons
            }
          end
          {
            name: (el[:uni].label),
            location: el[:uni].safe_value("location"),
            homepage: (el[:uni].safe_value "homepage"),
            coords: coords
          }
        end

      when "foerderprogramme"
        # NB We assume that funding programmes have exactly one involved organisation, which
        # is their funding organisation. Could verify this somewhere.
        @fps_by_org = FundingProgram
          .public_indis
          .includes(:current_deadline, :procedures_and_rules)
          .order(:label)
          .all
          .find_all { |fp| ((d = fp.current_deadline_value) && !d.past?) || fp.procedures_and_rules }
          .group_by { |fp| fp.involved_organisation_value.first }

        # Using `safe_value` when grouping to map to label to allow easy sorting.
        @orgs_by_state = @fps_by_org
          .keys
          .reject(&:nil?)
          .sort_by { |org| org.label }
          .find_all { |org| org.safe_value("country") == "Deutschland" && org.public? }
          .group_by { |org| org.safe_value("state") }
          .sort
      end

      render json: {
        term: term,
        html: render_to_string(partial: "api/fibonacci/#{term}", layout: false)
      }
    end
  end

  # Get collection data.
  #
  # @action GET
  # @url api/isus/collections/:isus_id
  def isus_collection
    @col = SciCollection.find_by(id: params[:id])
    if @col.nil?
      render json: { status: 404 }
      return
    elsif !User.anonymous_user.can_view_individual?(@col)
      render json: { status: 403 }
      return
    end

    if @col
      render json: {
        status: 200,
        have_data: true,
        klass: "SciCollection",
        id: @col.id,
        path: "/SciCollection/#{@col.id}",
        description: @col.safe_value("description"),
        opening_hours: @col.safe_value("opening_hours"),
        links: render_to_string("api/isus/links",
          formats: [:html],
          layout: false
        ),
        address: render_to_string("api/isus/address",
          formats: [:html],
          layout: false
        ),
        contact: render_to_string("api/isus/contact",
          formats: [:html],
          layout: false
        )
      }
    else
      render json: { have_data: false }
    end
  end

  private

  # outofthebox parameters
  OOTB_PARAMETERS = {
    "portale" => "Sammlungsportale",
    "sammlungskoordinationen" => "Sammlungskoordinationen",
    "foerderprogramme" => "Förderprogramme",
  }

  # returns a list of hashes [{ uni: university, coord: coordination }]
  def collection_coordinations
    # the datamodel does not implement a solid property for this quality; to check for
    # Sammlungskoordination of a university one has to check for Actors via related_actor,
    # that have the organisation_type "Sammlungskoordination"
    res = []
    Organisation.universities.select { |uni| uni.visibility == :public }.each do |uni|
      actors = uni.related_actor
      # return this university when at least one related_actor was found, that has
      # OrganisationType "Sammlungskoordination"
      actors = actors.select do |prop|
        act = prop.value
        (act.safe_value("organisation_type") == "Sammlungskoordination" && act.visibility == :public) ? true : false
      end
      # append this university + first actor to res if it has a Sammlungskoordination
      if actors.size > 0
        res << { uni: uni, coords: actors }
      end
    end
    # sort resulting list by the name of the uni's location
    res.sort do |x,y|
      (x[:uni].safe_value "location") <=> (y[:uni].safe_value "location")
    end
  end

  def result_to_json(r)
    {
      id: r[:id].to_i,
      label: r[:headline],
      more: r[:subheadline],
      typ: I18n.t(r[:klass], default: r[:klass]),
      url: request.base_url + "/" + r[:klass] + "/" + r[:id].to_s
    }
  end

  def get_single_document(id)
    begin
      indi = Individual.find(id)
      raise ErrorController::Forbidden unless indi.visibility == :public
      Searcher.new.find(id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end
