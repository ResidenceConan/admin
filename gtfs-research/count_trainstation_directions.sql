
CREATE OR REPLACE FUNCTION next_stop(stopid text, tripid text) RETURNS text AS $$
DECLARE
 current_sequence integer;
 next_sequence integer;
 next_stop_id text;
BEGIN
 DROP TABLE IF EXISTS route_stops;
 CREATE TEMP TABLE route_stops ON COMMIT DROP AS
 SELECT t.trip_id, st.stop_id, st.stop_sequence
	FROM stop_times st
	INNER JOIN trips t ON st.trip_id = t.trip_id
	WHERE t.trip_id = tripid;

SELECT stop_sequence into current_sequence FROM route_stops
	WHERE stop_id = stopid;

next_sequence = current_sequence + 1;

SELECT stop_id into next_stop_id FROM route_stops
	WHERE stop_sequence = next_sequence;

RETURN next_stop_id;
END;$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION unique_next_stops(stopid text)
RETURNS TABLE(stop_id text, stop_name text)
AS $$
BEGIN
RETURN QUERY
select ns.stop_id, ns.stop_name from
	(select distinct next_stop(stopid, stop_trips.trip_id) as stop_id from (
		select distinct t.trip_id, t.trip_short_name, st.stop_sequence
		from stops s
		inner join stop_times st on s.stop_id = st.stop_id
		inner join trips t on st.trip_id = t.trip_id
		where s.stop_id = stopid
	) as stop_trips
) as next_stop_ids
inner join stops ns on ns.stop_id = next_stop_ids.stop_id;
END;$$ LANGUAGE plpgsql;



-- see what kind of trains stop at the station
select count(*) as cnt, r.route_short_name from routes r
inner join trips t on t.route_id = r.route_id
inner join stop_times st on st.trip_id = t.trip_id
inner join stops s on st.stop_id = s.stop_id
where s.parent_station = '8503400'
group by r.route_short_name
order by cnt desc;


-- count directions
select distinct on (us.stop_name) s.stop_id, s.stop_name, us.stop_id, us.stop_name
from stops s, unique_next_stops(s.stop_id) as us
where parent_station = '8503400';

-- wetzikon: 5
-- uster: 5
-- bülach 8503400: 7
-- stettbach 8503147 (IC): 6

