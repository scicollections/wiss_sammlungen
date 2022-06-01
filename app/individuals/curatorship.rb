# Data Model: Collection Activity
class Curatorship < Activity
  # fill_on_create heißt, dass man beim Erstellen der weak Individual gebeten wird,
  # für dieses Predicate einen Wert auszuwählen.
  # (Ist nötig, weil zum Beispiel bei WebResource *nicht* alle owners beim
  # Erstellen gefüllt werden müssen.)
  property "curated_collection", :objekt, range: "SciCollection", inverse: "curator",
    cardinality: 1, is_owner: true, fill_on_create: true, affects_label: true

  # In der UI kann man das hier eh nicht bearbeiten. Aber ein böser Member könnte POST-Requests
  # faken, und sich so zum Curator einer Sammlung machen, die einen Curator hat,
  # den der Member bearbeiten darf. Dadurch bekäme der Member Edit-Rechte an der Sammlung.
  # Deshalb beschränke den Edit-Zugriff hier auf Manager.
  property "curator", :objekt, range: "Person", inverse: "curated_collection", cardinality: 1,
    is_owner: true, fill_on_create: true, editable_for: :manager, affects_label: true

  property "local_term", :string, cardinality: 1
  property "manager", :bool, cardinality: 1, default: false

  # (see Individual.weak?)
  def self.weak?
    true
  end

  # Auf sort_value wird von individual.sorted_properties zugegriffen wodurch
  # Curatorships, die durch glass gerendert werden, automatisch nach sort_value
  # sortiert werden. Die Sortierreihenfolge von Curatorship ist nur relevant
  # in der View von SciCollection, da nur hier mehrere Curatorships vorhanden
  # sein können. Ganz korrekt müsste man bei aber eigentlich noch den Kontext
  # miteinbeziehen können, die die Sortierung je nach Stelle an der dieses
  # Individual angezeigt wird, unterschiedlich sein könnte (v.a. bei weak
  # Individuals relevant).
  def sort_value
    if curator && curator.value.inline_label
      val = curator.value.inline_label
    elsif curator
      val = safe_value("curator")
    else
      val = ""
    end

    # Manager werden über Nicht-Managern angezeigt
    if safe_value("manager") == "true"
      "0#{val}"
    else
      "1#{val}"
    end
  end

  private

  def set_labels
    # Im Zuge der Erstellung von Curatorships ist hier ein Reload
    # notwendig, damit in den Revisionen ein vollständiges Label enthalten ist.
    if curator && Property.exists?(curator.id) && curator.reload && curator.value
      person_label = curator.value.label
    end
    str = "#{person_label} für #{curated_collection_value.label if curated_collection_value}"
    self.label = str
    self.inline_label = str
  end
end
