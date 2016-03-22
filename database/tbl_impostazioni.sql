--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.0
-- Dumped by pg_dump version 9.5.0

-- Started on 2016-03-22 04:36:16 CET

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET search_path = public, pg_catalog;

--
-- TOC entry 2419 (class 0 OID 68679)
-- Dependencies: 190
-- Data for Name: impostazioni; Type: TABLE DATA; Schema: public; Owner: smac
--

INSERT INTO impostazioni VALUES ('programma_attuale', '31');
INSERT INTO impostazioni VALUES ('programma_spento_nome', 'Spento');
INSERT INTO impostazioni VALUES ('programma_spento_descrizione', 'Il sistema rimarrà sempre spento, indipendentemente dalle temperature registrate');
INSERT INTO impostazioni VALUES ('programma_anticongelamento_nome', 'Anticongelamento');
INSERT INTO impostazioni VALUES ('programma_anticongelamento_descrizione', 'Il sistema si accenderà solo per evitare il congelamento. Cioè quando la temperatura ambientale scenderà al di sotto di quella rilevata da sensore di anticongelamento');
INSERT INTO impostazioni VALUES ('programma_anticongelamento_sensore', '0');
INSERT INTO impostazioni VALUES ('programma_manuale_nome', 'Manuale');
INSERT INTO impostazioni VALUES ('programma_manuale_descrizione', 'Il sistema proverà a mantenere la temperatura impostata manualmente');
INSERT INTO impostazioni VALUES ('programma_manuale_sensore', '0');
INSERT INTO impostazioni VALUES ('temperatura_anticongelamento', '5');
INSERT INTO impostazioni VALUES ('temperatura_manuale', '20');


-- Completed on 2016-03-22 04:36:16 CET

--
-- PostgreSQL database dump complete
--

