# Provides class methods for {Individual} related to permissions management.
#
# The following describes how our permissions system works. We track permissions for the following
# actions:
#
# - Individual
#     - view
#     - create
#     - edit
#     - delete
# - Property
#     - view
#     - edit (this includes creation and deletion)
# - Revision
#     - view
# - Other
#     - invite_user
#
# Note that in this classification, "Individual" can either mean "Individual instance" (e.g. for
# viewing) or "Individual class" (e.g. for creation). Similarly, "Property" can mean "Property
# instance" (e.g. for viewing a property instance) or "Individual class + predicate" aka. "Property
# group" (e.g. for viewing a property group section on an individual page or creating a new
# property instance). The effects of these distinctions are relatively straightforward. To see how
# they play out in more detail, look at the documentation of the `User#can_*_*?` methods quoted
# below.
#
# We have four user roles: public, member, manager and admin (see {User::ROLES}).
#
# Permissions can be specified in the following ways:
#
# - Individual
#     - view
#         - Individual class + user role with the `access_rule` method.
#         - Individual instance + user role with the `visible_for` property.
#     - create
#         - Individual class + user role with the `access_rule` method.
#     - edit
#         - Individual class + user role with the `access_rule` method.
#         - Individual instance + user instance (via `user.person`) with the `can_edit` property.
#         - Individual instance + user instance (via `user.person`) with the
#           {Person#automatically_editable} method.
#     - delete
#         - Individual class + user role with the `access_rule` method.
# - Property
#     - view
#         - Individual class + predicate + user role with the `visible_for` option in the `property`
#           method.
#     - edit
#         - Individual class + predicate + user role with the `editable_for` option in the
#           `property` method.
#
# This is how to use the system to determine whether a given user can do a given action:
#
# - Individual
#     - view: Use {User#can_view_individual?}. This is what it does:
#         > {include:User#can_view_individual?}
#     - create: Use {User#can_create_individual?}. This is what it does:
#         > {include:User#can_create_individual?}
#     - edit: Use {User#can_edit_individual?}. This is what it does:
#         > {include:User#can_edit_individual?}
#     - delete: Use {User#can_delete_individual?}. This is what it does:
#         > {include:User#can_delete_individual?}
# - Property
#     - view: Use {User#can_view_property?}. This is what it does:
#         > {include:User#can_view_property?}
#     - edit: Use {User#can_edit_property?}. This is what it does:
#         > {include:User#can_edit_property?}
# - Revision
#     - view: Use {User#can_view_revision?}. This is what it does:
#         > {include:User#can_view_revision?}
# - Other
#     - invite_user and all other possible future actions: Use {User#can?}. This is what it does:
#         > {include:User#can?}
#
# For the individual searches (`/discover` and `/search`), we store the individuals' visibility
# (see {Individual#visibility}) in the Elasticsearch index (see {Individual#provide_indexdata} and
# `Searcher#build_dsl_query`). (This means that the index has to be recreated when class-level
# `access_rule` visibility settings change.) Unfortunately, this is not possible for searching
# revisions, as revisions' visibility can depend on property visibility rules, which in turn can
# depend on the user's person (in the `can_edit` special rule).
#
module Accessible
  # Create an individual class level access rule.
  #
  # @param action [Symbol, Array<Symbol>] The action(s).
  # @param minimum_required_role [Symbol] The minimum require role to perform the action(s).
  def access_rule action: nil, minimum_required_role: nil
    raise "Bitte sowohl Action als auch Rolle angeben" unless action && minimum_required_role
    action = [action] unless action.is_a? Array

    # NOTE Dieser Hash ist einen Instanz-Variable der Individual-Klassen (nicht der
    # Individual-Instanzen!).
    @minimum_role_required ||= {}
    action.each do |act|
      @minimum_role_required[act.to_sym] = minimum_required_role.to_sym
    end
  end

  # @return [Symbol] The minimum required role to perform the action as defined on individual class
  #   level.
  def minimum_role_required action
    role = @minimum_role_required[action] if @minimum_role_required
    if role
      # Bei der angefragten Klasse wurde eine Mindest-Rolle hinterlegt. In diesem
      # Fall einfach diese Rolle zurückgeben.
      role
    elsif superclass <= Individual
      # Es wurde hier direkt keine Rolle angegeben, aber es gibt noch Superklassen,
      # bei denen vielleicht etwas spezifiziert wurde. Gehe also einen Schritt in der
      # Hierachie nach oben.
      superclass.minimum_role_required(action)
    else
      # Wir sind schon bei Individual angekommen, und es wurde nirgendwo eine Mindest-Rolle
      # hinterlegt. Gebe in diesem Fall die höchste Rolle (:admin) zurück.
      User::ROLES.last
    end
  end
end
