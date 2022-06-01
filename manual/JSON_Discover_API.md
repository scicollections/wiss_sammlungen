# JSON Discover API

## Authentifizierung

**Bearer-Token**

You may get your personal API key on https://portal.wissenschaftliche-sammlungen.de/users/edit 

The JSON API may be used without authentification but results are limited to publicly visible data.

## Individual-Datensatz

The JSON of an Individual's record can be retrieved by appending ".json" to the corresponding URL.

https://portal.wissenschaftliche-sammlungen.de/Organisation/19848

https://portal.wissenschaftliche-sammlungen.de/Organisation/19848.json

## JSON-Suche
https://portal.wissenschaftliche-sammlungen.de/discover.json

```
{
  term: "Erika Musterfrau",       #(query term)
  category: "collection",         #(see ESConfig.categories)
  from: 0,                        #offset
  size: 50,                       #result size
  facets: {                       # see ESConfig.facets
    place: ["Berlin","Hamburg"],
    collectiontype: "Geschichte & Archäologie"
  }
}
```

- term: full text search term
- category: filter for classes
- from: search offset
- size: search result size
- facets: hash of facet filters e.g. {place: \["Berlin","Hamburg"\]}

for category filter, facet filters and allowed values see https://portal.wissenschaftliche-sammlungen.de/discover.

