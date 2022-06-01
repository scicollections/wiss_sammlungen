# Individuals

require 'thread'
require 'timeout'

class Individual < ApplicationRecord
  # ActiveRecord Setup
  has_many :properties, inverse_of: :subject, class_name: "Property",
    foreign_key: :subject_id

  # Die folgende Assoziation wird zurzeit zum einen dafür verwendet, vor dem Löschen zu schauen,
  # ob dieses Individual noch mit Properties verbunden ist (in diesem Fall darf nicht
  # gelöscht werden), und zum anderen im EventManager, um diese Properties vorher zu löschen
  # (siehe auch Kommentar dort).
  has_many :is_objekt, inverse_of: :objekt, class_name: "PropertyObjekt",
    foreign_key: :objekt_id

  # Im Label sollte schon was stehen...
  validate :non_empty_label

  # Callbacks
  before_validation :before_validation_actions
  before_destroy :before_destroy_actions
  around_save :handle_label_affections

  # Indizierungsmöglichkeiten bereitstellen
  extend Indexable::ClassMethods
  include Indexable::InstanceMethods

  # Klassen-Methoden "access_rule" (zum Definieren von Rechten) und "minimum_role_required"
  # (zum Abfragen von Rechten) bereitstellen
  extend Accessible

  # Provide functionality in relation to hierarchies
  extend Hierarchical::ClassMethods

  # Das Label eines Individuals ist ja kein Property im eigentlichen Sinne, aber der Glass-Code
  # wird stark vereinfacht, wenn "label" wie ein gewöhnliches Prädikat verwendet werden kann.
  Ontology.register_predicate(self, "label", :string, { cardinality: 1 })

  # Ein weiteres Pseudo-Predicate ist "purl" für "Permanent URL"
  Ontology.register_predicate(self, "purl", :url, { cardinality: 1, editable_for: :nobody })

  def self.property predicate, type, options={}
    # Need to specify the property class in associations to make ActiveRecord instantiate
    # the right subclass of Property when accessing the properties.
    property_class = Ontology.resolve_property_class(type)

    # TODO Either remove the {predicate}_value methods or the safe_value(s) methods.
    method_name_value_access = :"#{predicate}_value" # Access Property value (both)

    # TODO PropertyGroup.new(...)
    Ontology.register_predicate self, predicate, type, options

    # Associations & Attribute Methods
    if options[:cardinality] == 1
      has_one predicate.to_sym, -> { where(predicate: predicate) }, class_name: property_class.to_s,
        foreign_key: :subject_id, dependent: :destroy

      # Accessing has_one value: individual#predicate_value
      define_method method_name_value_access do
        if options[:cached]
          # Wenn der Wert dieses Predicates gecached werden soll, dann greife hier auf den
          # Cache zu.
          send("#{predicate}_cache")
        else
          # Wenn kein Cache gewünscht ist, dann hole den Wert vom Property.
          prop = send(predicate)
          prop ? prop.value : nil
        end
      end
    else
      has_many predicate.to_sym, -> { where(predicate: predicate) }, class_name: property_class.to_s,
        foreign_key: :subject_id, dependent: :destroy

      # Accessing has_many values: individual#predicate_value
      # Marius: Maybe rename this to "predicate_values" in next refactoring?
      if type == :objekt
        define_method method_name_value_access do
          # Eager load objekt individual to reduce number of queries
          send(predicate).includes(:objekt).map(&:value)
        end
      else
        define_method method_name_value_access do
          # Note Marius 2017-07-06:
          # This could be done completely in the database with code like this:
          #
          #     Individual
          #       .joins(:is_objekt)
          #       .where(properties: { predicate: predicate, subject_id: id })
          #
          # I don't know whether it's faster or not. But it has the big advantage to allow code like
          # this to be completely handled by the database:
          #
          #     Organisation.public_indis.current_keeper_value.public_indis
          #
          # instead of what we'd do currently, which instantiates a lot of Ruby objects:
          #
          #    Organisation.public_indis.current_keeper_value.find_all(&:public?)
          #
          # But since this is a very basic location in the code base, such a change would need to
          # be thoroughly tested first.
          send(predicate).map(&:value)
        end
      end
    end
  end
  
  def self.infer_property predicate, path, type, options= {}
    method_name_value_access = "#{predicate}_value"
    
    Ontology.register_predicate self, predicate, type, options.merge({virtual: true})
    
    define_method predicate do
      ids = [id]
      props = nil
      path.each do |path_pred|
        props = Property.where(subject_id: ids, predicate: path_pred.to_s)
        ids = props.collect &:objekt_id
      end
      
      return props
    end
    
    define_method method_name_value_access do
      send(predicate).to_a.map(&:value).uniq
    end
  end

  # "cached: true" heißt, dass:
  # - es wird die Methode "visible_for_value" überschrieben, so dass dort auf das Feld
  #   "visible_for_cache" aus der Indivduals-Tabelle zugegriffen wird.
  # - im before_save von Propertys mit diesem Predicate wird der Cache aktualisiert
  # (- das Datenbank-Feld muss man selber anlegen)
  # (- diese Option ist zur Zeit nur für cardinality-one-Properties implementiert)
  property "visible_for", :string, cardinality: 1, options: ["public", "member", "manager"],
    visible_for: :member, editable_for: :manager, cached: true
  property "can_be_edited_by", :objekt, range: "Person", inverse: "can_edit",
    visible_for: :member

  property "info_text", :text, editable_for: :admin, cardinality: 1, cached: true
  property "has_memo", :objekt, range: "Memo", visible_for: :manager, inverse: "is_memo_for"
  
  property "same_as", :url

  # Alle dürfen erstmal alles sehen (dies kann über das "visible_for"-Property angepasst
  # werden).
  access_rule action: :view, minimum_required_role: :public

  # Jeder Member darf alles erstellen (die Sichtbarkeit wird aber vom EventManager
  # zunächst auf Members beschränkt).
  access_rule action: :create, minimum_required_role: :member

  # Alles bearbeiten und löschen dürfen nur Manager. Aber es gibt viele Fälle, in denen
  # einzelne Individuals auch von Membern bearbeitet (aber nicht gelöscht) werden dürfen,
  # zum Beispiel erhält man bei der Individual-Erstellung automatisch das Recht,
  # *diesen* Individual bearbeiten zu dürfen.
  access_rule action: [:edit, :delete], minimum_required_role: :manager

  # Diese Aktion könnte man auch "invite" nennen und dann nur bei Personen erlauben.
  # Dann müsste man aber die Berechnung der minimum_role_required ändern: Admins dürften
  # nicht mehr standardmäßig alles, denn auch Admins dürfen nicht Individuals einladen, die
  # keine Personen sind.
  access_rule action: :invite_user, minimum_required_role: :manager

  # Further Class Methods

  def self.predicates
    Ontology.predicates self
  end
  
  def self.predicates_for_manager
    predicates.select{|predicate| self.editable_for(predicate) == :manager}
  end

  def self.type_of predicate
    predicates[predicate.to_s][:type]
  end

  def self.class_of predicate
    Ontology.resolve_property_class(type_of(predicate))
  end

  def self.inverse_of predicate
    predicates[predicate.to_s][:inverse]
  end

  def self.visible_for predicate
    if predicates[predicate.to_s].nil?
      # applies if predicate has been renamed/deleted and 
      # therefore is no longer part of the ontology 
      return :manager 
    end
    predicates[predicate.to_s][:visible_for]
  end

  def self.editable_for predicate
    predicates[predicate.to_s][:editable_for]
  end

  # Die Optionen für ein Auswahlfeld mit vorgegebenen Werten, z.B. Person.gender
  def self.options_for predicate
    predicates[predicate.to_s][:options]
  end
  
  # flag whether to destroy a boolean porperty if it's false
  def self.bool_delete_on_false predicate
    predicates[predicate.to_s][:bool_delete_on_false]
  end

  # Instance Methods

  # Set label and strip it.
  def label= val
    super val.to_s.strip
  end

  def path
    "/#{type}/#{id}"
  end

  def purl
    "https://#{Maya::Application.config.mailhost["production"]}#{path}"
  end

  def predicates
    self.class.predicates
  end

  def reset_defaults
    predicates.each do |property_name, options|
      default_value = options[:default]
      self.send("#{property_name}=", default_value) if default_value != nil
    end
  end

  # @return Values for the given predicate.
  def safe_values predicate, arrayify=true
    val = []
    # Hier waere besser (Martin, Julian 2015-02-03)
    # self.predicates.has_key?(predicate)
    if self.respond_to?(predicate.to_sym)
      val = send(predicate.to_sym)
      val = [val] unless val.respond_to?(:first)
      val = val.map do |a|
        a.value if a.respond_to?(:value)
      end
      val = val.map do |a|
        if(a.respond_to?(:label))
          a.label
        else
          a
        end
      end
    end
    if (arrayify==false && val.compact.empty?)
      nil
    else
      val.compact
    end
  end

  # @return The first Safe Value.
  def safe_value predicate, stringify=true
    val = (safe_values predicate).first
    if stringify == true
      val.to_s
    else
      val
    end
  end

  
  def self.multi_safe_values predicates
    ids = all.pluck(:id)
    objs = Property.where(subject_id: ids, predicate: predicates)
    return objs.collect &:value 
  end
  


  def to_s
    inline_label
  end

  def inspect
    "#<#{self.class.name}/#{id} \"#{label}\">"
  end

  # @note Der Unterschied zu safe_values besteht unter anderem darin, dass dort ein Array von
  #   *Individuals* zurückgegeben wird.
  # @return [Array<Property>] The properties for the given predicate, sorted by their `sort_value`.
  def sorted_properties predicate
    if predicate == "label"
      properties = [PropertyString.new(subject: self, predicate: "label", data: label)]
    elsif predicate == "purl"
      properties = [PropertyUrl.new(subject: self, predicate: "purl", data: purl)]
    elsif respond_to?(predicate)
      properties = send(predicate)
      properties = [] if properties == nil
      properties = [properties] if !properties.respond_to? :each
    else
      properties = []
    end

    if type_of(predicate) == :objekt
      properties.sort do |a, b|
        cmp = (a.objekt.class_display <=> b.objekt.class_display)
        cmp == 0 ? (a.sort_value <=> b.sort_value) : cmp
      end
    else
      properties.sort { |a, b| a.sort_value <=> b.sort_value }
    end
  end

  def sorted_visible_properties predicate, user
    sorted_properties(predicate).find_all { |prop| user.can_view_property?(prop) }
  end

  def sorted_editable_properties predicate, user
    sorted_properties(predicate).find_all { |prop| user.can_edit_property?(prop) }
  end

  def objekt_ids predicate
    Property.where(subject_id: id, predicate: predicate).pluck(:objekt_id)
  end

  # @return [Hash] A hash from illegal objekt ids to reasons (Array of Strings).
  #
  # @note This isn't cached, so the user should cache it.
  #
  # @note This can be expanded by overriding this method, see hierarchical.rb for an example.
  def illegal_objekt_ids_with_reasons predicate
    reason = "Dieser Wert ist bereits ausgewählt."
    illegals = Hash.new { |h, k| h[k] = [] }
    objekt_ids(predicate).each { |id| illegals[id] << reason }
    illegals
  end

  def class_display
    if self.respond_to?(:class_from_predicate)
      classes = safe_values class_from_predicate
      unless classes.empty?
        classes.sort.join(", ")
      else
        I18n.t type
      end
    else
      I18n.t type
    end
  end

  def cardinality_of predicate
    if predicate.to_s == "label"
      1
    else
      hash = predicates[predicate.to_s]
      # TODO Introduce these checks for all similar methods.
      Hash === hash ? hash[:cardinality] : raise("Unknown predicate '#{predicate}' for #{type}")
    end
  end

  def type_of predicate
    self.class.type_of predicate
  end

  def class_of predicate
    self.class.class_of predicate
  end

  def range_of predicate
    predicates[predicate.to_s][:range]
  end

  # @return [String] The first (or only) range type for the given predicate.
  def singular_range_of predicate
    range = range_of predicate
    range.is_a?(Array) ? range.first : range
  end

  def inverse_of predicate
    predicates[predicate.to_s][:inverse]
  end

  def editable? predicate
    # TODO Dieser Code kann weg, wird in Maya nicht gebraucht
    predicates[predicate.to_s][:editable]
  end

  def is_owner? predicate
    # TODO Was ist, wenn es das Predicate nicht gibt?
    predicates[predicate.to_s][:is_owner]
  end

  # Get the owners. (This method is only used for weak individuals.)
  #
  # Diese werden als „related strong individuals“ in die Revision mit aufgenommen.
  # Der Return-Value hat die Form: [[individual, "predicate"], ...], da das Predicate
  # bei der Revisions-Erstellung benötigt wird.
  # Achtung: Predicates mit "is_owner: true" müssen "cardinality: 1" sein und
  # ein Reverse Property haben.
  # Außerdem wird ein weak Individual gelöscht, wenn eines seiner Owners gelöscht wird
  # (tritt bei einer vom IndividualManager kontrollierten Lösch-Kaskade auf).
  def owners
    # TODO für complex properties (oder zukünftige andere längere pfade) anpassen
    owners = predicates
      .select { |_, options| options[:is_owner] }
      .map    { |predicate, _| send(predicate) }
      .reject { |property| property.nil? }
      .map    { |property| [property.value, (property.inverse.predicate rescue nil)] }
      .reject { |individual, _| individual.nil? }
    # possible optimisation: nur die Ids holen
    if complex_property?
      owners_of_owners = owners.collect{|indi,_| indi.owners}.flatten(1)
      owners += owners_of_owners
    end
    owners
  end

  # @return [Boolean] Whether or not the instances of this class are weak individuals.
  #
  # @note Diese Methode soll in den Subklassen überschrieben werden.
  #   Man könnte darüber nachdenken, statt dem Überschreiben eine Klassen-Methode wie
  #   "property" und "access_rule" einzurichten, mit der man angeben kann, ob die entsprechende
  #   Klasse weak ist.
  def self.weak?
    false
  end

  # @return [Boolean] Whether or not this individual is weak.
  def weak?
    self.class.weak?
  end

  # @return [Boolean] Whether or not this individual class has a view.
  #
  # @note Diese Methode soll ggf. in den Subklassen überschrieben werden.
  #   Klassen ohne View sollen nicht in den Suchindex aufgenommen werden.
  def self.has_view?
    true
  end

  # (see .has_view?)
  def has_view?
    self.class.has_view?
  end
  
  def self.complex_property?
    false
  end

  # (see .complex_property?)
  def complex_property?
    self.class.complex_property?
  end

  # Get all {Person}s that are allowed to edit this {Individual}, granted
  # by implicit edit rights. Subclasses of {Individual} may define their own
  # implicit edit rights by overriding this method.
  #
  # @return [Array<Person>]
  def automatically_editable_by
    []
  end

  # @return Der Wert, der benutzt wird, wenn das Individual im Suchtextfeld eines anderen vorkommt.
  def index_value
    label
  end

  # @return Der Wert, der benutzt wird, wenn das Individual in einer Facette eines anderen vorkommt.
  def facet_value
    label
  end

  # Determine the individual's visibility. The logic goes like this:
  #
  # - If the individual is strong:
  #     - If it has a `visible_for` property:
  #         - Return the `visible_for` value.
  #     - Else:
  #         - Return the role set with `access_rule`.
  # - Else (i.e. the individual is weak):
  #     - Get the owners' visibilities and return the most restrictive one.
  #
  # @return [Symbol]
  def visibility
    # Check for owners is neccessary because in the process of deleting a string individual the 
    # properties linking them to a weak individuals are deleted before their weak indi.
    # The owners of this weak indi can therefore not be determined.
    if weak? && !owners.empty?
      indices = owners.map { |indi, _| User::ROLES.index(indi.visibility) }
      User::ROLES[indices.max]
    else
      (visible_for_value || self.class.minimum_role_required(:view)).to_sym
    end
  end

  # @return [Boolean] Whether the individual is public.
  def public?
    visibility == :public
  end

  # Get publically visible individuals. This only works for strong individuals, as the weak's
  # visibility depends on their owners.
  #
  # @return [ActiveRecord_Relation]
  #
  # @note This can be chained with other ActiveRecord methods like
  #   "where", and does its filtering in the database. Therefore, using "Individual.public_indis.all" is
  #   better than doing "Individual.all.find_all(&:public?)" (even though both expressions yield
  #   exactly the same result).
  def self.public_indis
    raise StandardError, "Individual.public_indis can't be used for weak individuals" if weak?

    if minimum_role_required(:view) == :public
      # If this class is public by default, the database value can be empty or "public".
      where(visible_for_cache: [nil, :public])
    else
      # If this class is *not* public by default, the database value *has* to be "public".
      where(visible_for_cache: :public)
    end
  end
  
  # there is a special implementation for person.rb
  # @return [Array<Hash>] a list of hashes in the form of [{ "slugXY": "Campaign17", "status": "done"}, ...]
  def survey_states
    if c = Campaign.current
      if self.instance_of? c.targetclass.constantize
        campaign_states = Campaign.current.campaigns_and_states_for_indis([self])
        campaign_states.collect{|slug,status| {slug: slug, status: status}}
      end
    end
  end
  
  
  def to_hash user=User.anonymous_user, path=nil, recursion_safeguard=0
    preds = predicates.select{|pred, _| user.can_view_property? subject: self, predicate: pred}
    indihash = {id: id, 
                label: label, 
                permanent_url: purl, 
                class: self.class.name,
                class_specific_localised: class_display}
    preds.select!{|pred,pred_hash| pred != "label" && pred != "purl" && ((pred_hash[:inverse] != path) || pred_hash[:inverse].nil?)}
    
    preds.each do |pred, pred_hash|
      
      data = nil
      if pred_hash[:type] == :objekt
        objs = self.try("#{pred}_value")
        objs = [objs] unless objs.is_a? Array
        objs.compact!
        objs.select!{|obj| user.can_view_individual? obj} # visibility filter
        
        #if !pred_hash[:range].constantize.weak?
        if objs.collect{|obj| obj.weak?}.any? && recursion_safeguard < 1 # resursive limit
          data = objs.collect{|obj| obj.to_hash(user,pred,recursion_safeguard+1)} # recursive call
        else
           data = objs.collect{|obj| {id: obj.id, 
                                      class: obj.class.name, 
                                      permanent_url: obj.purl, 
                                      label: obj.label,
                                      class_specific_localised: obj.class_display,
                                      same_as: obj.safe_values("same_as")
                                      }}
                                      
        end
      else
        data = self.safe_values(pred)
      end
      data = nil if data.length == 0
      data = data[0] if (data != nil) && (pred_hash[:cardinality] == 1)
      indihash[pred] = data if data != nil
    end
    return indihash
  end

  # Private Instance Methods

  private

  def non_empty_label
    # Bin mir nicht sicher ob es Probleme geben könnte, falls Weak-Indis
    # zwischengespeichert werden mit einem leeren Label. Diese also
    # vorsichtshalber ignorieren.
    unless weak? || (label && label.size > 0)
      errors.add(:label, "Die Bezeichnung darf nicht leer sein.")
    end
  end

  def before_validation_actions
    set_labels
    shorten_indi_label
  end

  def handle_label_affections
    # Speichere alle Individuals, deren Label von uns abhängt.
    # Allerdings nur, falls sich unser eigenes Label geändert hat.
    # ACHTUNG: Es ist nirgendwo festgelegt, dass bei Objekt-Properties
    # mit :affects_label = true sich nur das Label des Objekt-Individuals
    # auf das Label des Subject-Individuals auswirkt.
    # Im Moment ist dies der Fall, sollte sich das ändern, muss der Code
    # an dieser Stelle darauf angepasst werden.
    label_changed = label_changed?

    yield

    if label_changed
      Thread.new(id) do |idt|
        File.open(Rails.root.join("tmp","label_affection.lock"), File::RDWR|File::CREAT, 0644) do |f|
          begin
            # Auf Lockfile warten
            Timeout::timeout(5*60) { f.flock(File::LOCK_EX) }
          rescue Timeout::Error => e
            Logger.new("log/label_affection.log").warn("Couldn't acquire exclusive lock (Timeout of 5 min reached)")
          else
            # Connection Pool um verwaiste Verbindungen zu verhindern:
            # https://bibwild.wordpress.com/2014/07/17/activerecord-concurrency-in-rails4-avoid-leaked-connections/
            ActiveRecord::Base.connection_pool.with_connection do |con|
              Individual.find(idt).is_objekt
                .includes(:subject)
                .find_all { |prop| prop.subject.predicates[prop.predicate][:affects_label] }
                .each { |x| x.subject.save }
            end
          end
        end
      end
    end
  end

  def set_labels
    self.inline_label = label
  end

  def shorten_indi_label
    if label != nil
      self.label = label[0, 254]
    end
  end

  # Habe das "_actions" genannt, um analog zu "before_save_actions" zu sein. Aber da hier ja
  # gar keine Actions passieren, vielleicht umbenennen?
  def before_destroy_actions
    if properties.reload.any? || is_objekt.reload.any?
      # Wenn man hier false zurückgibt, dann wird das löschen nicht durchgefürt. Stattdessen
      # gibt indi.destroy false zurück.
      false
    end

    # prevent deletion of Ontology Constants
    if descriptive_id.present?
      raise ErrorController::UndeletableIndividual, "This Individual '#{self.label}'(#{self.id}) is an ontology constant as indicated by its non-empty descriptive_id value '#{self.descriptive_id}' and thus must not be deleted."
    end
  end
end
