# pgRouting Recherche

## raster2pgsql

## load rasters into pgsql

```
CREATE EXTENSION postgis;
-- ALTER SYSTEM SET postgis.enable_outdb_rasters TO True;
-- ALTER SYSTEM SET postgis.gdal_enabled_drivers TO 'ENABLE_ALL';
-- SELECT pg_reload_conf();
```

```
-- retrieve GeoTiff information
gdalinfo swissALTI3D.tif

-- load tif into pgsql
raster2pgsql -s 21781 -d -I -C -M swissALTI3D.tif -F -t 100x100 public.swissalti3d | psql --username=postgres -d isochrone

-- retrieve height for a specific point (really slow and ugly query, bear with me)
select sub.rid, sub.height from (select rid, ST_Value(rast, 1, ST_GeomFromText('POINT(2761212 1193751)', 21781)) as height from swissalti3d) as sub where sub.height > 0;
```
### Links

* [raster2pgsql Tutorial](http://suite.opengeo.org/docs/latest/dataadmin/pgGettingStarted/raster2pgsql.html)
* [ST_Value_Count](https://postgis.net/2014/09/26/tip_count_of_pixel_values/)
* [ST_Value](https://postgis.net/docs/manual-dev/RT_ST_Value.html)

### Notes

* is CH1903+(2056)  or CH1903(21781) used?

## isochrones


create database and fill it with OSM data

```
CREATE DATABASE routing;
CREATE EXTENSION postgis;
CREATE EXTENSION pgrouting;

-- not sure about the encoding, UTF-8 will display a warning
shp2pgsql -W "LATIN1" chur_lines.shp public.routing > chur_lines.sql

\c routing
\i chur_lines.sql
```

create routing topology

```
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

```
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

```
-- http://docs.pgrouting.org/2.3/en/doc/src/tutorial/topology.html#topology
UPDATE routing SET x1 = st_x(st_startpoint(geom)),
                   y1 = st_y(st_startpoint(geom)),
                   x2 = st_x(st_endpoint(geom)),
                   y2 = st_y(st_endpoint(geom)),
                   cost_len  = st_length_spheroid(geom, 'SPHEROID["WGS84",6378137,298.25728]');
```

IDEA: split a line into segments and calculate for each segment the incline and slope

```
CREATE OR REPLACE FUNCTION segments(IN integer)
  RETURNS TABLE(geom geometry) AS
$BODY$
BEGIN
   RETURN QUERY
   SELECT ST_LineSubstring(the_geom, $1*n/length,
   CASE
	WHEN $1*(n+1) < length THEN $1*(n+1)/length
	ELSE 1
   END) As new_geom
   FROM
        (SELECT ST_LineMerge(routing.geom) AS the_geom, cost_len As length FROM routing where gid = 1) AS t
   CROSS JOIN generate_series(0,10000) AS n WHERE n*$1/length < 1;
END
$BODY$
  LANGUAGE plpgsql

SELECT * FROM segments(1, 100);
```

get start and end points for each segment

```
-- get start and end points
SELECT st_x(st_startpoint(geom)) AS start_x,
       st_y(st_startpoint(geom)) AS start_y,
       st_x(st_endpoint(geom)) AS end_x,
       st_y(st_endpoint(geom)) AS end_y
       FROM segments(1, 100);
```

get the height for a specific point

```
-- get height
CREATE OR REPLACE FUNCTION get_height(geom geometry)
    RETURNS TABLE(height double precision) as
$BODY$   
    select sub.height from (select rid, ST_Value(rast, 1, $1) as height from swissalti3d) as sub where sub.height > 0;
$BODY$
      LANGUAGE sql;

select * from get_height(ST_GeomFromText('POINT(2759519.0304392 1191991.26991665)', 21781));
```

calculate incline

```
```

calculate incline_metres_in_altitude

```
```

calculate slope

```
```

calculate slope_metres_in_altitude

```
```

calculate effective_kilometers
effective_kilometers = distance + incline_metres_in_altitude/100 + slope_metres_in_altitude/150 (if slope_metres_in_altitude/slope > 20%)

```
```

### Links

* [Drive-time Isochrones from a single Shapefile using QGIS](https://anitagraser.com/2017/09/11/drive-time-isochrones-from-a-single-shapefile-using-qgis-postgis-and-pgrouting/)
* [Public transport isochrones with pgRouting](https://anitagraser.com/2013/07/07/public-transport-isochrones-with-pgrouting/)
  * the travel time is used as the cost
