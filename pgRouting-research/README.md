# pgRouting Recherche

## raster2pgsql

## load rasters into pgsql

```sql
CREATE EXTENSION pgrouting;
CREATE EXTENSION postgis;
-- ALTER SYSTEM SET postgis.enable_outdb_rasters TO True;
-- ALTER SYSTEM SET postgis.gdal_enabled_drivers TO 'ENABLE_ALL';
-- SELECT pg_reload_conf();
```

```bash
-- retrieve GeoTiff information
gdalinfo swissALTI3D.tif

-- load tif into pgsql
raster2pgsql -s 2056 -d -I -C -M swissALTI3D.tif -t 100x100 public.swissalti3d | psql --username=postgres -d <db-name>
```

```sql
-- retrieve height for a specific point
select sub.rid, ST_Value(sub.rast, 1, ST_GeomFromText('POINT(2759519.0304392 1191991.26991665)', 2056)) as height from
  (select rid, rast from swissalti3d where ST_Intersects(rast, ST_GeomFromText('POINT(2759519.0304392 1191991.26991665)', 2056))) as sub;

```

### Links

* [raster2pgsql Tutorial](http://suite.opengeo.org/docs/latest/dataadmin/pgGettingStarted/raster2pgsql.html)
* [ST_Value_Count](https://postgis.net/2014/09/26/tip_count_of_pixel_values/)
* [ST_Value](https://postgis.net/docs/manual-dev/RT_ST_Value.html)

## isochrones


create database and fill it with OSM data

``` bash
osm2pgrouting --f chur.osm --conf /usr/local/share/osm2pgrouting/mapconfig_for_pedestrian.xml --dbname routing --username postgres --clean

-- import with osm2pgsql instead
osm2pgsql -E 2056 -d routing -U postgres -H localhost -P 5432 -W chur.osm

\c <db-name>
\i chur_lines.sql
```

create routing topology

```sql
ALTER TABLE routing
    ADD COLUMN source integer,
    ADD COLUMN target integer,
    ADD COLUMN cost_len double precision,
    ADD COLUMN x1 double precision,
    ADD COLUMN y1 double precision,
    ADD COLUMN x2 double precision,
    ADD COLUMN y2 double precision;

SELECT pgr_createTopology('routing', 0.001, 'geom', 'gid', 'source', 'target');
```

test if we have any multiline trings, if so we'll have trouble calculation start and end points (see [here](https://gis.stackexchange.com/questions/116414/take-from-multilinestring-the-start-and-end-points))

```sql
SELECT COUNT(
        CASE WHEN ST_NumGeometries(geom) > 1 THEN 1 END
    ) AS multi, COUNT(geom) AS total
FROM routing;

-- if we do no have any multilinestring we can safely convert the geometry type (I'm not sure if we have to deal with the srid)
ALTER TABLE routing
    ALTER COLUMN geom TYPE geometry(LineString, 0)
    USING ST_GeometryN(geom, 1);
```

calculate start and end points and the distance

```sql
-- http://docs.pgrouting.org/2.3/en/doc/src/tutorial/topology.html#topology
UPDATE routing SET x1 = st_x(st_startpoint(geom)),
                   y1 = st_y(st_startpoint(geom)),
                   x2 = st_x(st_endpoint(geom)),
                   y2 = st_y(st_endpoint(geom)),
                   cost_len = st_length_spheroid(ST_transform(st_setsrid(geom, 2056), 4326), 'SPHEROID["WGS84",6378137,298.25728]');
-- TODO: fix unnecessary transformation                   
```

IDEA: split a line into segments and calculate for each segment the incline and slope

```sql
CREATE OR REPLACE FUNCTION segments(gid_input integer, segment_length integer default 100)
  RETURNS TABLE(geom geometry) AS
$BODY$
BEGIN
   RETURN QUERY
   SELECT ST_LineSubstring(the_geom, segment_length*n/length,
   CASE
	WHEN segment_length*(n+1) < length THEN segment_length*(n+1)/length
	ELSE 1
   END) As new_geom
   FROM
        (SELECT ST_LineMerge(routing.geom) AS the_geom, cost_len As length FROM routing where routing.gid = gid_input) AS t
   CROSS JOIN generate_series(0,10000) AS n WHERE n*segment_length/length < 1;
END
$BODY$
  LANGUAGE plpgsql

SELECT * FROM segments(1, 100);
```

get start and end points for each segment

```sql
-- get start and end points
SELECT st_startpoint(geom) AS start,
       st_endpoint(geom) AS end
       FROM segments(1, 100);
```

transform 4326 point to 2056 (not necessary if osm file is imported with srid 2056)

```sql
CREATE OR REPLACE FUNCTION transform_to_2056(geom geometry)
    RETURNS TABLE(height geometry) as
$BODY$   
    SELECT ST_Transform(ST_SetSRID($1, 4326), 2056);
$BODY$
      LANGUAGE sql;
```

get point as text

```sql
SELECT ST_AsText(st_startpoint(geom)) AS start,
       ST_AsText(st_endpoint(geom)) AS end
       FROM segments(1, 100);
-- test points on https://map.geo.admin.ch
```


get the height for a specific point

```sql
-- get height
CREATE OR REPLACE FUNCTION get_height(geom geometry)
    RETURNS TABLE(height double precision) as
$BODY$   
    select ST_Value(ST_SetSRID(sub.rast, 2056), 1, $1) as height from
      (select rid, rast from swissalti3d where ST_Intersects(ST_SetSRID(rast, 2056), $1)) as sub;
$BODY$
      LANGUAGE sql;

select * from get_height(ST_GeomFromText('POINT(2759519.0304392 1191991.26991665)', 2056));

SELECT get_height(st_startpoint(geom)) AS start,
       get_height(st_endpoint(geom)) AS end
       FROM segments(1, 100);
```

calculate incline and decline, incline_metres_in_altitude, decline_metres_in_altitude

```sql
-- function is not really necessary, keeping it for further help writing functions
CREATE OR REPLACE FUNCTION slope(gid_input integer) RETURNS RECORD AS $$
DECLARE
  ret RECORD;
  segment RECORD;
  incline INTEGER := 0;
  decline INTEGER := 0;
  incline_metres_in_altitude DOUBLE PRECISION := 0.0;
  decline_metres_in_altitude DOUBLE PRECISION := 0.0;
BEGIN
  FOR segment IN
    SELECT get_height(st_startpoint(geom)) AS start, get_height(st_endpoint(geom)) AS destination FROM segments($1, 1)
  LOOP
    IF segment.start < segment.destination THEN
      incline := incline + 1;
      incline_metres_in_altitude := incline_metres_in_altitude + (segment.destination - segment.start);
    ELSEIF segment.start > segment.destination THEN
      decline := decline + 1;
      decline_metres_in_altitude := decline_metres_in_altitude + segment.start - segment.destination;
    ELSE
      -- and now what?
    END IF;
  END LOOP;
  SELECT incline, decline, incline_metres_in_altitude, decline_metres_in_altitude INTO ret;
RETURN ret;
END;$$ LANGUAGE plpgsql;

SELECT * FROM slope(1) as(incline INTEGER, decline INTEGER, incline_metres_in_altitude DOUBLE PRECISION, decline_metres_in_altitude DOUBLE PRECISION);
```


calculate effective_kilometres ([see Leistungskilometer](https://de.wikipedia.org/wiki/Leistungskilometer))
> effective_kilometres = distance + incline_metres_in_altitude/100 + slope_metres_in_altitude/150 (if slope_metres_in_altitude/slope > 20%)

```sql
CREATE OR REPLACE FUNCTION calc_effective_kilometres(gid_input integer) RETURNS DOUBLE PRECISION AS $$
DECLARE
  segment RECORD;
  distance DOUBLE PRECISION;
  incline INTEGER := 0;
  decline INTEGER := 0;
  incline_metres_in_altitude DOUBLE PRECISION := 0.0;
  decline_metres_in_altitude DOUBLE PRECISION := 0.0;
  effective_kilometres DOUBLE PRECISION := 0;
BEGIN
  FOR segment IN
    SELECT get_height(st_startpoint(geom)) AS start, get_height(st_endpoint(geom)) AS destination FROM segments($1, 1)
  LOOP
    IF segment.start < segment.destination THEN
      incline := incline + 1;
      incline_metres_in_altitude := incline_metres_in_altitude + (segment.destination - segment.start);
    ELSEIF segment.start > segment.destination THEN
      decline := decline + 1;
      decline_metres_in_altitude := decline_metres_in_altitude + segment.start - segment.destination;
    END IF;
  END LOOP;
  select st_length_spheroid(ST_transform(st_setsrid(geom, 2056), 4326), 'SPHEROID["WGS84",6378137,298.25728]') into distance from routing where gid = $1;
  effective_kilometres := distance + incline_metres_in_altitude/100;
  IF decline != 0 AND decline_metres_in_altitude/decline > 0.2 THEN
    effective_kilometres := effective_kilometres + decline_metres_in_altitude/150;
  END IF;
  RETURN effective_kilometres;
END;
$$ LANGUAGE plpgsql;

select * from calc_effective_kilometres(1);
UPDATE routing SET cost_len = calc_effective_kilometres(gid); -- does take some time
```

### Isochrones mit Segmenten

Problem: Eine Kante im Routing-Graphen geht jeweils von einem Startpunkt des Ways bis zu Endpunkt, bzw. zur nächsten Kreuzung.
Dementsprechend geben Isochrone nur Strassen an, die "bis zum Ende" erreicht werden. Sie werden verworfen, wenn irgendwo auf einer Strasse (kann mehrere km lang sein) das Limit erreicht wird.
Wir brauchen eine kleinere Auflösung des Routing-Graphen.

Idee: Mit `segments()` die Strassen (Ways) unterteilen und damit den Routing-Graphen aufbauen:

Tabelle für neue Ways vorbereiten
```sql
CREATE TABLE ways_segments (
    id serial primary key,
    geom geometry(LINESTRING, 4326),
    source integer,
    target integer,
    cost_len double precision,
    x1 double precision,
    y1 double precision,
    x2 double precision,
    y2 double precision;
);
```

Segmente aufsplitten (hier in 10m Segmente)
```sql
INSERT INTO ways_segments(geom)
    SELECT new_geom FROM ways
        CROSS JOIN segments(gid::integer, 10) as new_geom;
```

Routing-Topologie erstellen (als Toleranz wird ca. 10m umgerechnet in WGS84-Grad gewählt, sonst gibt es zu wenige Vertices)
```sql
SELECT pgr_createTopology('ways_segments', 0.0000895, 'geom', 'id', 'source', 'target');
```

Restliche Spalten befüllen
```sql
UPDATE ways_segments SET x1 = st_x(st_startpoint(geom)),
                   y1 = st_y(st_startpoint(geom)),
                   x2 = st_x(st_endpoint(geom)),
                   y2 = st_y(st_endpoint(geom)),
                   cost_len = st_length_spheroid(geom, 'SPHEROID["WGS84",6378137,298.25728]');
```

Tabelle mit Linien als Isochrone ausgeben (Start-vertex 10262, 500m Distanz)
```sql
SELECT * FROM ways_segments WHERE id IN (
    SELECT edge
    FROM pgr_drivingdistance('select id, source, target, cost_len as cost from ways_segments', 10262, 500)
    );
```


### Links
* [osm2pgrouting](https://github.com/pgRouting/osm2pgrouting)
* [Drive-time Isochrones from a single Shapefile using QGIS](https://anitagraser.com/2017/09/11/drive-time-isochrones-from-a-single-shapefile-using-qgis-postgis-and-pgrouting/)
* [Public transport isochrones with pgRouting](https://anitagraser.com/2013/07/07/public-transport-isochrones-with-pgrouting/)
  * the travel time is used as the cost
