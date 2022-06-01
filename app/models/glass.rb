# A glorified view helper.
class Glass
  def initialize controller, survey: false
    @controller = controller
    @glass_mode = survey
    @viewpath = survey ? "air" : "glass"
  end

  def humanize individual, predicate
    # Bei SAD gab es häufig den Fall, dass ein und dasselbe Prädikat bei verschiedenen
    # Individuals verschieden übersetzt wurde. Deshalb waren die Prädikate in de.yml
    # nach den Individual-Klassen sortiert. Daher sah die Funktion so aus:
    #
    # I18n.translate "#{individual.class.name}.#{predicate}"
    #
    # Bei Maya ist das (bisher) nicht der Fall, deswegen können wir hier die Prädikate
    # auf der ersten Ebene haben:
    I18n.translate predicate
  end

  #
  # INLINE
  #

  def inline individual, predicate, locals: {}
    viewable = @controller.current_user.can_view_property?(subject: individual, predicate: predicate)
    unless viewable
      return
    end
    editable = @controller.current_user.can_edit_property?(subject: individual, predicate: predicate)
    # to allow custom property group views (e.g. tables) set an optional template
    # for now it's only used for holdings
    range_klass = individual.range_of(predicate)
    if range_klass && range_klass.is_a?(String)
      template = "#{@viewpath}/inline/property_group/#{range_klass.underscore}"
      template = @controller.template_exists?(template, [], true) ? template : nil
    end

    @controller.render_to_string(
      partial: "#{@viewpath}/inline/property_group",
      locals: {
        individual: individual,
        predicate: predicate,
        editable: editable,
        partial: template
      }.merge(locals)
    ).html_safe
  end

  def inline_individual individual, locals: {}
    template = "#{@viewpath}/inline/#{individual.class.name.underscore}"
    if @controller.template_exists?(template, [], true)
      @controller.render_to_string(
        partial: template,
        locals: { individual: individual }.merge(locals)
      ).html_safe
    else
      individual.to_s
    end
  end

  def inline_property property, locals: {}
    @controller.render_to_string(
      partial: "#{@viewpath}/inline/property",
      locals: { property: property }.merge(locals)
    ).html_safe
  end

  #
  # EDIT
  #

  def edit individual, predicate, locals: {}
    # Spezialfall für das Label von Personen.
    if predicate == "label" && individual.is_a?(Person)
      return edit_individual individual, label: true, locals: locals
    end

    props = individual.sorted_editable_properties(predicate, @controller.current_user)
    prop_class = individual.class_of(predicate)
    complex_prop = individual.range_of(predicate).try(:constantize).try(:complex_property?)
    if props.any? && prop_class != PropertySelectOption
      props.map { |prop| edit_property(prop, locals: locals) }.join.html_safe
    elsif individual.cardinality_of(predicate) == 1 && prop_class != PropertyObjekt
      # We need to display a form even though there is no property in the DB.
      prop = prop_class.new(subject: individual, predicate: predicate)
      edit_property(prop, locals: locals)
    elsif individual.cardinality_of(predicate) == 1 && complex_prop
      prop = prop_class.new(subject: individual, predicate: predicate)
      edit_property(prop, locals: locals)
    elsif prop_class == PropertySelectOption && individual.cardinality_of(predicate) != 1
      #individual.predicates[predicate.to_s][:options].map { |opt| edit_property(prop, locals: locals) }.join.html_safe
      opts = individual.predicates[predicate.to_s][:options]
      dummyprops = opts.map { |opt| prop_class.new(subject: individual, predicate: predicate, data: opt) }
      dummyHash = Hash[dummyprops.map {|p| [p.data,p]}]
      propsHash = Hash[props.map {|p| [p.data,p]}]
      propsHash = dummyHash.merge(propsHash)
      
      propsHash.values.map { |prop| edit_property(prop, locals: locals) }.join.html_safe
    end
  end
  
  def inline_predicate individual, predicate, locals: {}
    @controller.render_to_string(
      partial: "#{@viewpath}/edit/inline_predicate",
      locals: { individual: individual, predicate: predicate }.merge(locals)
    ).html_safe
  end
  
  def inline_edit individual, predicate, locals: {}
    # Spezialfall für das Label von Personen.
    if predicate == "label" && individual.is_a?(Person)
      return edit_individual individual, label: true, locals: locals
    end

    props = individual.sorted_editable_properties(predicate, @controller.current_user)
    prop_class = individual.class_of(predicate)
    
    if props.any? && prop_class != PropertySelectOption
      props.map { |prop| inline_edit_property(prop, locals: locals) }.join.html_safe
    elsif individual.cardinality_of(predicate) == 1 && prop_class != PropertyObjekt
      # We need to display a form even though there is no property in the DB.
      prop = prop_class.new(subject: individual, predicate: predicate)
      inline_edit_property(prop, locals: locals)
    elsif prop_class == PropertySelectOption && individual.cardinality_of(predicate) != 1
      #individual.predicates[predicate.to_s][:options].map { |opt| inline_edit_property(prop, locals: locals) }.join.html_safe
      opts = individual.predicates[predicate.to_s][:options]
      dummyprops = opts.map { |opt| prop_class.new(subject: individual, predicate: predicate, data: opt) }
      dummyHash = Hash[dummyprops.map {|p| [p.data,p]}]
      propsHash = Hash[props.map {|p| [p.data,p]}]
      propsHash = dummyHash.merge(propsHash)
      
      propsHash.values.map { |prop| inline_edit_property(prop, locals: locals) }.join.html_safe
    end
  end
  
  def inline_edit_property property, locals: {}
    @controller.render_to_string(
      partial: "#{@viewpath}/edit/property_inline",
      locals: { property: property }.merge(locals)
    ).html_safe
  end

  def edit_property property, locals: {}
    @controller.render_to_string(
      partial: "#{@viewpath}/edit/property",
      locals: { property: property }.merge(locals)
    ).html_safe
  end

  # @param subject [Individual] The subject individual. We need this for double owner weak
  #   individuals (like {Curatorship}) to decide which owner needs to be displayed in the form.
  #   Basically, this is what's called `inline_individual` in the {UpdateController}.
  def edit_individual individual, label: false, subject: nil, locals: {}
    unless locals[:as_table]
      template = "#{@viewpath}/edit/#{individual.class.name.underscore}"
      template += "_label" if label
    else
      template = "air/table_row"
    end
    
    if @controller.template_exists?(template, [], true)
      @controller.render_to_string(
        partial: template,
        locals: { individual: individual, subject: subject }.merge(locals)
      ).html_safe
    else
      ("<em>Bitte das Template #{@viewpath}/edit/_#{template}.html.erb erstellen!</em>").html_safe
    end
  end
  
  def table_cell individual, predicate, locals: {}
    props = individual.sorted_editable_properties(predicate, @controller.current_user)
    if props.any?
      props.map { |prop| table_cell_property(prop, locals: locals) }.join.html_safe
    else
      prop_class = individual.class_of(predicate)
      prop = prop_class.new(subject: individual, predicate: predicate)
      table_cell_property(prop, locals: locals)
    end
  end
  
  def table_cell_property property, locals: {}
    @controller.render_to_string(
      partial: "air/cell_property",
      locals: { property: property }.merge(locals)
    )
  end

  #
  # NEW
  #

  def new individual, predicate
    @controller.render_to_string(
      partial: "#{@viewpath}/new/property",
      locals: { predicate: predicate, individual: individual }
    ).html_safe
  end
end
