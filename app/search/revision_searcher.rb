class RevisionSearcher
  attr_reader :results, :has_results, :has_more,
              :from, :size, :filter, :facets,
              :indi

  def initialize
    ## Input defaults
    @user = nil
    @indi = nil
    @from = 0
    @size = 50    # (default) number of docs per page
    @filter = {}

    ## Output initial values
    @results      = nil
    @has_results  = false
    @has_more     = false
    @hits         = 0

    @facets = {
      type: { name: "Typen", terms: {} },
      user: { name: "Benutzer_in", terms: {} },
      action: { name: "Aktion", terms: {} },
      creator_role: { name: "Rolle", terms: {} },
      campaign: {name: "Kampagne", terms: {} },
      predicate: { name: "Eigenschaft", terms: {} }
    }
  end

  def configure args = {}
    @user = args[:user]      if args[:user]
    @indi = args[:indi].to_i if args[:indi]
    @from = args[:from].to_i if args[:from]
    @size = args[:size].to_i if args[:size]

    self.filter = args[:filter] if args[:filter]
  end

  def filter= hsh
    @filter = {}
    facets.keys.each do |k|
      if hsh[k].is_a?(Array)
        hsh[k] -= [""]
        hsh[k].compact!
        @filter[k] = hsh[k] unless hsh[k].empty?
      end
    end if hsh.is_a?(Hash)
  end

  def add_filter key, val
    key = key.to_sym unless key.nil?
    if facets.keys.include? key and !val.nil? and val != ""
      @filter[key] ||= []
      @filter[key] += [val]
      @filter[key].uniq!
    end
  end

  def remove_filter key, val
    key = key.to_sym unless key.nil?
    if @filter[key].is_a?(Array)
      @filter[key] -= [val]
      if @filter[key].length == 0
        @filter.delete(key)
      end
    end
  end

  def execute
    raise ErrorController::Forbidden if @user.nil? || @user.public?

    @results = Revision

    # lokal vs. global
    if @indi
      # Wir sind auf der lokalen Revisionliste eines Individuals.
      # Nehme deshalb nur Revisionen, die mit diesem Individual zu tun haben, d.h. entweder
      # wurde dieses Individual selbst (oder eines seiner Properties) geändert, oder es wurde
      # ein weak Individual geändert, das an unserem Individual dran hängt.
      sql = "? IN (subject_id, old_individual_id, new_individual_id, " +
                  "occured_at_related_strong_individual_id, other_related_strong_individual_id, complex_property_parent_individual_id)"
      @results = @results.where(sql, @indi)
    else
      # Wir sind auf der globalen Revisionsliste. Deshalb zeigen keine inversen Revisionen
      # (sonst würden alle Revisionen von Objekt-Properties doppelt erscheinen), und zeige
      # außerdem keine Revisionen, die hier ausgeblendet werden sollen (wann das der Fall ist
      # erfährt man im Kommentar in event_manager.rb).
      @results = @results.where(hide_on_global_list: false, inverse: false)

    end

    # Filter
    if @filter[:user]
      @results = @results.where(user_id: @filter[:user])
    end
    if @filter[:type]
      @results = @results.where("subject_type IN (:types) OR " +
                                "individual_type IN (:types) OR " +
                                "old_objekt_type IN (:types) OR " +
                                "new_objekt_type IN (:types) OR " +
                                "occured_at_related_strong_individual_type IN (:types) OR " +
                                "other_related_strong_individual_type IN (:types) OR " +
                                "complex_property_parent_individual_type IN (:types)",
                                types: @filter[:type])
    end
    if @filter[:action]
      @results = @results.where(action: @filter[:action])
    end
    if @filter[:creator_role]
      @results = @results.where(creator_role: @filter[:creator_role])
    end
    if @filter[:campaign]
      @results = @results.where(campaign_slug: @filter[:campaign])
    end
    if @filter[:predicate]
      @results = @results.where(predicate: @filter[:predicate])
    end
    
    # local vs global AR includes (and facet assembling call)
    if @indi
      @results = @results.includes(:user, :new_objekt, :old_objekt)
                         .includes(:old_individual, :new_individual, :subject, :complex_property_parent_individual)
      # Ich include auch old_individual, new_individual und subject, obwohl es klar ist,
      # dass es sich dabei um den lokalen Individual handelt, weil unten bei der Sichtbarkeits-
      # Überprüfung auch auf diese zugegriffen wird.
    else
      # Auswahllisten zusammenstellen
      # NB We want to do this *before* we add the includes to the query, because `pluck`
      # will transform them into joins, which makes the facet queries very slow.
      if from == 0
        assemble_facets
      end

      @results = @results.includes(:user, :subject, :old_individual, :new_individual,
                                   :new_objekt, :old_objekt,
                                   :occured_at_related_strong_individual,
                                   :other_related_strong_individual,
                                   :complex_property_parent_individual)
    end

    # Sortiere nach Id und nicht nach created_at, weil Revisions manchmal in derselben
    # Sekunde erstellt werden (zB die Anfangs-Properties bei Person-Erstellung).
    @results = @results.order("revisions.id DESC").limit(@size).offset(@from)

    # Ist nicht ganz präzise, aber Ok
    @has_more = @results.length == @size

    # Werfen jetzt erst die Revisionen raus, die der Benutzer nicht sehen darf. Wichtig ist,
    # dass wir *vorher* festgestellt haben, ob es weitere Resultate gibt. Denn wenn wir hier
    # reduzieren, dann kann sich @results.length verringern, und kleiner als @size werden.
    # (Das war unsere Methode, um festzustellen, ob es (möglicherweise) weitere Ergebnisse
    # gibt.) Nun kann es natürlich sein, dass eine Ergebnisseite viel weniger als @size
    # Ergebnisse enthält, und so kann ein Member auch merken, dass etwas "im Verborgenen"
    # passiert. Zur Zeit ist es aber sehr schwer, die Sichtbarkeit auf DB-Ebene zu ermitteln.
    # Das würde etwas einfacher werden, wenn "visible_for" in der Individuals-Tabelle steht,
    # trotzdem bestünde weiterhin die Herausforderung, die auf Klassenebene festgelegte
    # Mindestrolle zu berücksichtigen. (Ein weitere Problem sind Revision-Subjects, die weake
    # Individuals sind. Ihre Sichtbarkeit hängt von den Owners ab. Dies könnte man
    # vielleicht umgehen, indem man in solchen Fällen statt dem Subject die Sichtbarkeit der
    # related strong Individuals abfragt.)
    @results = @results.find_all { |rev| @user.can_view_revision?(rev) }

    @has_results = @results.length > 0
  end

  private

  def assemble_facets
    # TODO Maybe find a way to get all user records in one query?
    @facets[:user][:terms] = @results
      .pluck(:user_id)
      .reject(&:nil?)
      .group_by { |id| id }
      .map { |id, values| [id, (User.find(id).to_s rescue "User #{id}"), values.count] }
      .sort { |(id1, name1, _), (id2, name2, _)|
      if id1 == @user.id
        -1
      elsif id2 == @user.id
        1
      else name1 <=> name2
      end
    }

    @facets[:type][:terms] = @results
      .pluck(:subject_type, :individual_type, :old_objekt_type, :new_objekt_type)
      .map { |types| types.uniq } # wegen z.B. Person bei Person als verknüpfter Akteur gesetzt
      .flatten
      .reject(&:nil?)
      .group_by { |type| type }
      .map { |key, values| [key, I18n.t(key), values.count] }
      .sort_by { |_, display, _| display }

    @facets[:action][:terms] = @results
      .pluck(:action)
      .reject{|a| a.nil? }
      .group_by{|a| a }
      .collect{|key, values| [key, I18n.t(key, default: key, scope: "actions"), values.count] }
      .sort_by { |_, display, _| display }

    @facets[:creator_role][:terms] = @results
      .pluck(:creator_role)
      .reject{|a| a.nil? }
      .group_by{|a| a }
      .collect{|key, values| [key, I18n.t(key, default: key), values.count] }
      .sort_by { |_, display, _| display }

    @facets[:campaign][:terms] = @results
      .pluck(:campaign_slug)
      .reject{|a| a.nil? }
      .group_by{|a| a }
      .collect{|key, values| [key, I18n.t(key, default: key), values.count] }
      .sort_by { |_, display, _| display }

    @facets[:predicate][:terms] = @results
      .pluck(:predicate)
      .reject{|a| a.nil? }
      .group_by{|a| a }
      .collect{|key, values| [key, I18n.t(key, default: key), values.count] }
      .sort_by { |_, display, _| display }
  end
end
