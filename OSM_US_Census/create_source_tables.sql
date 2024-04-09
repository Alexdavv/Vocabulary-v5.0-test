/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may NOT use this file except IN compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to IN writing, software
* distributed under the License is distributed ON an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Alex Davydov, Oleg Zhuk, Christian Reich
* Date: 2019
**************************************************************************/

DROP TABLE IF EXISTS sources.osm;
CREATE TABLE sources.osm
(
	gid integer,
	id integer,
	country varchar(254),
	name varchar(254),
	enname varchar(254),
	locname varchar(254),
	offname varchar(254),
	boundary varchar(254),
	adminlevel integer,
	wikidata varchar(254),
	wikimedia varchar(254),
	timestamp varchar(254),
	note varchar(254),
	rpath varchar(254),
	iso3166_2 varchar(254),
	geom devv5.geometry(MultiPolygon,4326)
);

CREATE INDEX idx_osm_id ON SOURCES.OSM (ID);

DROP TABLE IF EXISTS sources.cb_us_division_500k;
CREATE TABLE sources.cb_us_division_500k
(
	gid int,
	divisionce varchar(1),
	affgeoid varchar(10),
	geoid varchar(1),
	name varchar(100),
	lsad varchar(2),
	aland double precision,
	awater double precision,
	geom devv5.geometry(MultiPolygon,4326)
);

DROP TABLE IF EXISTS sources.cb_us_region_500k;
CREATE TABLE sources.cb_us_region_500k
(
	gid int,
	regionce varchar(1),
	affgeoid varchar(10),
	geoid varchar(1),
	name varchar(100),
	lsad varchar(2),
	aland double precision,
	awater double precision,
	geom devv5.geometry(MultiPolygon,4326)
);