--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- Data for Name: driver_sensori; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY driver_sensori (id, nome, parametri) FROM stdin;
1	DHT11	\N
2	DHT22	\N
\.


--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('driver_sensori_id_driver_seq', 2, true);


--
-- PostgreSQL database dump complete
--

