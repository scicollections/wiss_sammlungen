# Achtung: Änderungen an dieser Datei werden nur berücksichtigt, wenn man den Server
# bzw. die Console neu startet. Das liegt daran, das hier mit der Rails-Konvention
# gebrochen wird, nach der in einer Datei immer genau eine Klasse definiert werden soll,
# die auch genau wie der Dateiname heißt.

# Attentions: These classes might not be available in the controllers (or even in models) in
# development mode. If in doubt, use the error classes defined in ErrorController.
# TODO Consolidate these classes with the ones defined in ErrorController and/or make sure that
# these classes are loaded, even in development mode.

# Ein allgemeiner Maya-Fehler.
#
# Inspiriert von: https://github.com/ryanb/cancan/blob/master/lib/cancan/exceptions.rb#L3
class Error < StandardError; end

# Exceptions für die Api-Services

# The API service is not available.
class ApiServiceNotAvailable < Error; end

# The GND ID is invalid.
class InvalidGndId < Error; end

# The ISIL is invalid.
class InvalidIsil < Error; end

# The geo name ID is invalid.
class InvalidGeoNameId < Error; end

# Rechtesystem-Exceptions

# The action is forbidden.
class ForbiddenAction < Error; end
