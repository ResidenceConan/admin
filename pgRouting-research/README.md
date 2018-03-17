# pgRouting Recherche

## raster2pgsql

## load rasters into pgsql

```
CREATE DATABASE raster2pgsqltest;
CREATE SCHEMA public;

CREATE EXTENSION postgis;
-- ALTER SYSTEM SET postgis.enable_outdb_rasters TO True;
-- ALTER SYSTEM SET postgis.gdal_enabled_drivers TO 'ENABLE_ALL';
-- SELECT pg_reload_conf();
```

```
-- retrieve GeoTiff information
gdalinfo swissALTI3D.tif

-- load tif into pgsql
raster2pgsql -s 21781 -d -I -C -M swissALTI3D.tif -F -t 100x100 public | psql --username=postgres -d raster2pgsqltest

-- retrieve height for a specific point (really slow and ugly query, bear with me)
select sub.rid, sub.height from (select rid, ST_Value(rast, 1, ST_GeomFromText('POINT(2761212 1193751)', 21781)) as height from public) as sub where sub.height > 0;
```
### Links

* [raster2pgsql Tutorial](suite.opengeo.org/docs/latest/dataadmin/pgGettingStarted/raster2pgsql.html)
* [ST_Value_Count](https://postgis.net/2014/09/26/tip_count_of_pixel_values/)
* [ST_Value](https://postgis.net/docs/manual-dev/RT_ST_Value.html)

## isochrones

### Links

* [Public transport isochrones with pgRouting](https://anitagraser.com/2013/07/07/public-transport-isochrones-with-pgrouting/)
  * the travel time is used as the cost
