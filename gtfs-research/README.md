# GTFS Recherche

## Daten
- [geOps Daten](http://gtfs.geops.ch/#completefeed)
- [GTFS Spezifikation](http://gtfs.org/reference)

## Schema

Das Schema basiert auf <https://github.com/tyleragreen/gtfs-schema>

Musste selbst ergänzt werden, da im geOps Datensatz zusätzliche Felder vorkommen sowie Felder, die eigentlich "required" wären, nicht überall gefüllt sind

### Notizen
- [Zeichnung des Schemas](https://camo.githubusercontent.com/eb8ef475708f33dc1134c33e0283cdf1c767cfa7/687474703a2f2f692e696d6775722e636f6d2f774554397250702e706e67)
- Eine Route in `routes` beschreibt z.B. eine Fahrt eines Busses zu einem gewissen Zeitpunkt an einem Tag. Eine Buslinie kann so hunderte `routes` haben
- Ein Trip in `trips` scheint 1:1 auf `routes` zu mappen und verweist zusätzlich auf `calendar_dates`
    - Die `service_id`s in `calendar_dates` kommen mehrmals vor. Es gibt einen Eintrag für jeden Tag, an dem ein spezifischer `trip` (und damit `route`) angeboten wird.
- `stop_times` beschreiben die Trips bzw. Routen im Detail, wann sie an welchen Haltestellen (`stops`) sind
- In `stops` werden Haltestellen mit Name und Koordinaten beschrieben
    - Die Koordinaten sind in WGS84, aber etwas ungenau (wohl gleiche Problematik wie bei SA)
    - Eine Haltestelle kann auch eine Kante sein. Die übergeordnete Haltestelle wird mit `parent_station` erfasst

### Beispiele
- Alle Ankunfts- und Abfahrtszeiten an einer Haltestelle
``` sql
select * from stop_times where stop_id = '8588098';
```

## Integration
- [SQLAlchemy](https://www.sqlalchemy.org/) für OR-Mapping in Python
    - [Mit Autoload bestehende DB übernehmen](https://www.blog.pythonlibrary.org/2010/09/10/sqlalchemy-connecting-to-pre-existing-databases/)
- <https://github.com/OpenTransitTools/gtfsdb>
    - Erzeugt SQLAlchemy mappings, aber müsste angepasst werden, damit es mit geOps Daten funktioniert
    - Für python2.7 geschrieben
