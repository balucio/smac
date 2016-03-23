--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.0
-- Dumped by pg_dump version 9.5.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS smac;
--
-- Name: smac; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE smac WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE smac OWNER TO postgres;

\connect smac

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: parametri_sensore; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE parametri_sensore AS (
	id smallint,
	nome character varying,
	descrizione character varying,
	posizione point,
	abilitato boolean,
	incluso_in_media boolean,
	id_driver smallint,
	nome_driver character varying,
	parametri_driver character varying
);


ALTER TYPE parametri_sensore OWNER TO postgres;

--
-- Name: report_programma; Type: TYPE; Schema: public; Owner: smac
--

CREATE TYPE report_programma AS (
	id_programma integer,
	nome_programma character varying(64),
	descrizione_programma text,
	temperature_rif numeric(9,4)[],
	t_anticongelamento numeric(9,4),
	sensore_rif smallint,
	nome_sensore_rif character varying(64)
);


ALTER TYPE report_programma OWNER TO smac;

--
-- Name: report_sensore; Type: TYPE; Schema: public; Owner: smac
--

CREATE TYPE report_sensore AS (
	data_ora timestamp without time zone,
	id_sensore smallint,
	nome_sesore character varying,
	temperatura numeric(9,4),
	umidita numeric(9,4)
);


ALTER TYPE report_sensore OWNER TO smac;

--
-- Name: situazione_sensore; Type: TYPE; Schema: public; Owner: smac
--

CREATE TYPE situazione_sensore AS (
	id_sensore smallint,
	num_sensori smallint,
	nome_sensore character varying,
	temperatura numeric,
	temperatura_min numeric,
	temperatura_med numeric,
	temperatura_max numeric,
	tendenza_temperatura numeric,
	umidita numeric,
	umidita_min numeric,
	umidita_med numeric,
	umidita_max numeric,
	tendenza_umidita numeric,
	ultimo_aggiornamento timestamp without time zone,
	ultima_previsione timestamp without time zone
);


ALTER TYPE situazione_sensore OWNER TO smac;

--
-- Name: aggiorna_crea_dettaglio_programma(integer, smallint, time without time zone, smallint); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION aggiorna_crea_dettaglio_programma(p_pid integer, p_day smallint, p_time time without time zone, p_temp_id smallint) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
   chk_time time DEFAULT null;
BEGIN
	IF NOT esiste_programma(p_pid) THEN
		RAISE EXCEPTION 'Programma non esistente --> %', p_id;
	END IF;

	SELECT ora INTO chk_time
	  FROM dettaglio_programma
	 WHERE id_programma = p_pid AND giorno = p_day AND ora = p_time;

	IF chk_time IS NOT NULL THEN
	
		UPDATE dettaglio_programma
		   SET t_riferimento = p_temp_id
		 WHERE id_programma = p_pid AND giorno = p_day AND ora = p_time;
		 
	ELSE
		INSERT INTO dettaglio_programma
		     VALUES (p_pid, p_day, p_time, p_temp_id);
		     
	END IF;

END;
$$;


ALTER FUNCTION public.aggiorna_crea_dettaglio_programma(p_pid integer, p_day smallint, p_time time without time zone, p_temp_id smallint) OWNER TO smac;

--
-- Name: aggiorna_crea_programma(character varying, text, numeric[], smallint, integer); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION aggiorna_crea_programma(p_nome character varying, p_descrizione text, p_temps numeric[], p_sensore smallint DEFAULT 0, p_id integer DEFAULT NULL::integer) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
DECLARE
   d smallint;
BEGIN

	IF p_id IS NULL OR p_id <= 0 THEN
		INSERT INTO programmi(nome_programma, descrizione_programma, temperature_rif, sensore_rif)
		     VALUES (p_nome, p_descrizione, p_temps, p_sensore) RETURNING id_programma INTO p_id;
	ELSE
		UPDATE programmi
		  SET nome_programma = p_nome,
	              descrizione_programma = p_descrizione,
	              temperature_rif = p_temps,
		      sensore_rif = p_sensore
	        WHERE id_programma = p_id;

	        -- E' necessario eliminare tutte le programmazioni relative alle temperature non più esistenti
	        d = array_length( p_temps, 1 )::smallint;
	        UPDATE dettaglio_programma SET t_riferimento = d WHERE id_programma = p_id AND t_riferimento > d;

	        RETURN p_id;
	END IF;

	-- Crezione di una misurazione t_anticongelamento per tutti i giorni nel caso di nuovo programma
	FOR d IN 1..7 LOOP
		INSERT INTO dettaglio_programma(id_programma, giorno, ora, t_riferimento)
		     VALUES (p_id, d, '00:00:00'::time, 0::smallint);
        END LOOP;

        RETURN p_id;

END;
$$;


ALTER FUNCTION public.aggiorna_crea_programma(p_nome character varying, p_descrizione text, p_temps numeric[], p_sensore smallint, p_id integer) OWNER TO smac;

--
-- Name: aggiorna_dati_giornalieri(smallint, date); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION aggiorna_dati_giornalieri(sensore smallint, giorno date DEFAULT now()) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    synop_min timestamp;
    synop_med timestamp;
    synop_max timestamp;

    syrep_min timestamp;
    syrep_max timestamp;

    l_id_synop_temp_min numeric(9,4);
    l_id_synop_temp_max numeric(9,4);

    l_id_syrep_temp_min numeric(9,4);
    l_id_syrep_temp_max numeric(9,4);

    l_id_umidita_min numeric(9,4);
    l_id_umidita_max numeric(9,4);

BEGIN

    synop_min = giorno - '1 day'::interval + '18:00'::time;
    synop_med = giorno + '6:00'::time;
    synop_max = giorno + '18:00'::time;

    syrep_min = giorno - '1 day'::interval + '23:30'::time;
    syrep_max = giorno + '23:30'::time;

    
    -- tabella di comodo per salvare i dati dei sensori nell'intervallo utile
    DROP TABLE IF EXISTS log_giornata;
    CREATE TEMPORARY TABLE log_giornata(
        data_ora timestamp,
        id_misurazione bigint,
        temperatura numeric(9,4),
        umidita numeric(9,4)
    );

    INSERT INTO log_giornata
         SELECT data_ora, id_misurazione, temperatura, umidita
           FROM misurazioni
          WHERE id_sensore = sensore
            AND data_ora BETWEEN synop_min AND syrep_max;

    -- id temperatura SYNOP minima
    SELECT id_misurazione INTO l_id_synop_temp_min
      FROM log_giornata
     WHERE data_ora BETWEEN synop_min AND synop_med
  ORDER BY temperatura ASC, data_ora ASC
     LIMIT 1;

    -- id temperatura SYNOP massima
    SELECT id_misurazione INTO l_id_synop_temp_max
      FROM log_giornata
     WHERE data_ora BETWEEN synop_med AND synop_max
  ORDER BY temperatura DESC, data_ora DESC
     LIMIT 1;

    -- id temperatura SYREP minima
    SELECT id_misurazione INTO l_id_syrep_temp_min
      FROM log_giornata
     WHERE data_ora BETWEEN syrep_min AND syrep_max
  ORDER BY temperatura ASC, data_ora ASC
     LIMIT 1;

    -- id temperatura SYREP massima
    SELECT id_misurazione INTO l_id_syrep_temp_max
      FROM log_giornata
     WHERE data_ora BETWEEN syrep_min AND syrep_max
  ORDER BY temperatura DESC, data_ora DESC
     LIMIT 1;

    -- id umidita minima
    SELECT id_misurazione INTO l_id_umidita_min
      FROM log_giornata
     WHERE data_ora BETWEEN syrep_min AND syrep_max
  ORDER BY umidita ASC, data_ora ASC
     LIMIT 1;

    -- id umidita massima
    SELECT id_misurazione INTO l_id_umidita_max
      FROM log_giornata
     WHERE data_ora BETWEEN syrep_min AND syrep_max
  ORDER BY umidita DESC, data_ora DESC
     LIMIT 1;

  -- Provo ad aggiornare il giorno
  UPDATE dati_giornalieri
     SET id_synop_temp_min = l_id_synop_temp_min,
         id_synop_temp_max = l_id_synop_temp_max,
         id_syrep_temp_min = l_id_syrep_temp_min,
         id_syrep_temp_max = l_id_syrep_temp_max,
         id_umidita_min = l_id_umidita_min,
         id_umidita_max = l_id_umidita_max
   WHERE data = giorno AND id_sensore = sensore;

   -- Se la precedente riga esisteva, l'update è andato a buon fine
   -- pertanto l'insert non viene eseguto
   INSERT INTO dati_giornalieri(
       data,
       id_sensore,
       id_synop_temp_min,
       id_synop_temp_max,
       id_syrep_temp_min,
       id_syrep_temp_max,
       id_umidita_min,
       id_umidita_max
    ) SELECT
        giorno,
        sensore,
        l_id_synop_temp_min,
        l_id_synop_temp_max,
        l_id_syrep_temp_min,
        l_id_syrep_temp_max,
        l_id_umidita_min,
        l_id_umidita_max
    WHERE NOT EXISTS (
        SELECT 1
          FROM dati_giornalieri
         WHERE data = giorno AND id_sensore = sensore
    );

END;$$;


ALTER FUNCTION public.aggiorna_dati_giornalieri(sensore smallint, giorno date) OWNER TO smac;

--
-- Name: aggiorna_situazione(); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION aggiorna_situazione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
   s_att situazione%ROWTYPE;
BEGIN
    SELECT * INTO s_att FROM situazione
     WHERE situazione.id_sensore = new.id_sensore;

    IF s_att.id_sensore IS NULL THEN
       
        INSERT INTO situazione(data_ora, id_sensore, temperatura, umidita)
            VALUES (NEW.data_ora, NEW.id_sensore, NEW.temperatura, NEW.umidita);
    ELSE
       UPDATE situazione
          SET data_ora = NEW.data_ora,
              temperatura = NEW.temperatura,
              umidita = NEW.umidita
        WHERE id_sensore = s_att.id_sensore;
  
    END IF;

    PERFORM pg_notify('NUOVA_SITUAZIONE', NEW.id_sensore::text || '|' || NEW.temperatura::text || '|' || NEW.umidita::text);

    RETURN NEW;
END;$$;


ALTER FUNCTION public.aggiorna_situazione() OWNER TO smac;

--
-- Name: aggiorna_tendenza(interval, interval); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION aggiorna_tendenza(campione interval DEFAULT '01:00:00'::interval, previsione interval DEFAULT '00:10:00'::interval) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    l_sensore smallint;
    previsione_temperatura numeric(9,4);
    previsione_umidita numeric(9,4);
BEGIN

  
    FOR l_sensore IN SELECT situazione.id_sensore 
                       FROM situazione
                 INNER JOIN sensori ON(situazione.id_sensore = sensori.id_sensore)
                      WHERE ultimo_aggiornamento IS NULL
                         OR ultimo_aggiornamento <= (NOW() - previsione)
        LOOP

            SELECT previsione_mq(l_sensore, 'temperatura', campione, previsione) INTO previsione_temperatura;
            SELECT previsione_mq(l_sensore, 'umidita', campione, previsione) INTO previsione_umidita;

            UPDATE situazione
               SET tendenza_temperatura = previsione_temperatura,
                   tendenza_umidita =  previsione_umidita
             WHERE id_sensore = l_sensore;

	    UPDATE sensori SET ultimo_aggiornamento = NOW() WHERE id_sensore = l_sensore;
    END LOOP;
END;$$;


ALTER FUNCTION public.aggiorna_tendenza(campione interval, previsione interval) OWNER TO smac;

--
-- Name: dati_programma(integer); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION dati_programma(progr_id integer DEFAULT NULL::integer) RETURNS SETOF report_programma
    LANGUAGE plpgsql ROWS 10
    AS $$
DECLARE
    progdata report_programma;
    curr_progr text;
    t_anticongelamento numeric(9,4);
    t_manuale numeric(9,4);
    id_sensore_rif smallint DEFAULT 0;
    nome_sensore_rif varchar(64) default null;
BEGIN

    IF progr_id IS NULL THEN
        SELECT get_setting('programma_attuale','-1'::text) INTO progr_id;
    END IF;

    t_anticongelamento = get_setting('temperatura_anticongelamento'::varchar(64),'5'::text)::numeric(9,4);

    CASE progr_id::smallint

        -- sistema spento
        WHEN -1 THEN

            RETURN QUERY SELECT
               -1,
               get_setting('programma_spento_nome'::varchar(64),'Spento'::text)::varchar(64),
               get_setting('programma_spento_descrizione'::varchar(64),'Sistema Spento'::text),
               ARRAY[]::numeric(9,4)[],
               t_anticongelamento,
               null::smallint,
               null::varchar(64);

        -- sistema in risparmio energia (anticongelamento)
        WHEN 0 THEN

            id_sensore_rif = get_setting('programma_anticongelamento_sensore'::varchar(64),'0'::text)::smallint;
            SELECT nome_sensore INTO nome_sensore_rif from elenco_sensori(null) where id_sensore = id_sensore_rif;

            RETURN QUERY
               SELECT
                  0,
                  get_setting('programma_anticongelamento_nome'::varchar(64),'Anticongelamento'::text)::varchar(64),
                  get_setting('programma_anticongelamento_descrizione'::varchar(64),'Sitema in Anticongelamento'::text),
		  (ARRAY[ t_anticongelamento, null,null, null, null])::numeric(9,4)[],
		  t_anticongelamento,
		  id_sensore_rif,
		  nome_sensore_rif;
        WHEN 32767 THEN

            t_manuale = get_setting('temperatura_manuale'::varchar(64),'20'::text)::numeric(9,4);
            id_sensore_rif = get_setting('programma_manuale_sensore'::varchar(64),'0'::text)::smallint;
            SELECT nome_sensore INTO nome_sensore_rif from elenco_sensori(null) where id_sensore = id_sensore_rif;

            RETURN QUERY SELECT
               32767,
               get_setting('programma_manuale_nome'::varchar(64),'Manuale'::text)::varchar(64),
               get_setting('programma_manuale_descrizione'::varchar(64),'Sistema in Manuale'::text),
               (ARRAY[ t_manuale, null,null, null, null])::numeric(9,4)[],
               t_anticongelamento,
               id_sensore_rif,
               nome_sensore_rif;

	-- richiesta specifico id programma
        ELSE
            
            RETURN QUERY
               SELECT p.id_programma,
                      p.nome_programma,
                      p.descrizione_programma,
                      p.temperature_rif,
                      t_anticongelamento,
                      p.sensore_rif,
                      e.nome_sensore
                 FROM programmi p
            LEFT JOIN elenco_sensori(null) AS e
                   ON e.id_sensore = p.sensore_rif
                WHERE p.id_programma = progr_id;

       END CASE;

       RETURN;
       
END$$;


ALTER FUNCTION public.dati_programma(progr_id integer) OWNER TO smac;

--
-- Name: dati_sensore(smallint, interval, interval); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION dati_sensore(l_id_sensore smallint DEFAULT NULL::smallint, campione interval DEFAULT '01:00:00'::interval, target interval DEFAULT '00:10:00'::interval) RETURNS SETOF situazione_sensore
    LANGUAGE plpgsql ROWS 10
    AS $_$
DECLARE
    dati_sensore situazione_sensore;
    cond_where text DEFAULT null;
    query text DEFAULT null;

BEGIN

    dati_sensore.id_sensore = 0;
    dati_sensore.nome_sensore = null;
    dati_sensore.num_sensori = 0;

    -- verifico che non sia la media dei sensori
    l_id_sensore = @ COALESCE(l_id_sensore, 0);

    IF l_id_sensore = 0 THEN

        -- ricalcolo se necessario tutte le tendenze
        PERFORM aggiorna_tendenza(campione, target);

        -- ottengo i valori medi attuali
        SELECT 0::smallint,
               get_setting('sensore_media_nome'::varchar(64),'Media'::text)::Varchar(64),
               COUNT(sns.id_sensore)::smallint,
               AVG(stz.temperatura),
               AVG(stz.tendenza_temperatura),
               AVG(stz.umidita),
               AVG(stz.tendenza_umidita),
               MAX(stz.data_ora),
               MAX(sns.ultimo_aggiornamento)
          INTO dati_sensore.id_sensore,
               dati_sensore.nome_sensore,
               dati_sensore.num_sensori,
               dati_sensore.temperatura,
               dati_sensore.tendenza_temperatura,
               dati_sensore.umidita,
               dati_sensore.tendenza_umidita,
               dati_sensore.ultimo_aggiornamento,
               dati_sensore.ultima_previsione
          FROM situazione AS stz
    INNER JOIN sensori AS sns
            ON (stz.id_sensore = sns.id_sensore)
         WHERE sns.incluso_in_media = true
           AND sns.abilitato = true;
    ELSE
        -- La select estrae comunque un id_sensore anche se non esite una situazione
        SELECT sns.id_sensore,
               sns.nome_sensore,
               CASE WHEN stz.id_sensore IS NULL THEN 0 ELSE 1 END,
               stz.temperatura,
               stz.tendenza_temperatura,
               stz.umidita,
               stz.tendenza_umidita,
               stz.data_ora,
               sns.ultimo_aggiornamento
          INTO dati_sensore.id_sensore,
               dati_sensore.nome_sensore,
               dati_sensore.num_sensori,
               dati_sensore.temperatura,
               dati_sensore.tendenza_temperatura,
               dati_sensore.umidita,
               dati_sensore.tendenza_umidita,
               dati_sensore.ultimo_aggiornamento,
               dati_sensore.ultima_previsione
          FROM situazione AS stz
    RIGHT JOIN sensori AS sns
            ON (stz.id_sensore = sns.id_sensore)
         WHERE sns.id_sensore = l_id_sensore
           AND sns.abilitato = true;
    END IF;
 
    -- verifico se ci sono risultati
    IF dati_sensore.num_sensori >= 1 THEN

        -- aggiorno se necessario e solo se non è stata richiesta la media
        IF dati_sensore.id_sensore <> 0::smallint 
           AND (dati_sensore.ultima_previsione IS NULL
            OR dati_sensore.ultima_previsione <= (NOW() - target)) THEN

            SELECT previsione_mq(dati_sensore.id_sensore, 'temperatura', campione, target) 
              INTO dati_sensore.tendenza_temperatura;
                  
            SELECT previsione_mq(dati_sensore.id_sensore, 'umidita', campione, target) 
              INTO dati_sensore.tendenza_umidita;
        
            UPDATE situazione
               SET tendenza_temperatura = dati_sensore.tendenza_temperatura,
                   tendenza_umidita = dati_sensore.tendenza_umidita
             WHERE situazione.id_sensore = dati_sensore.id_sensore;
                 
            UPDATE sensori
               SET ultimo_aggiornamento = NOW()
             WHERE sensori.id_sensore = dati_sensore.id_sensore;

        END IF;

        query = 'SELECT MIN(temperatura),'
                    || 'AVG(temperatura),'
                    || 'MAX(temperatura),'
                    || 'MIN(umidita),'
                    || 'AVG(umidita),'
                    || 'MAX(umidita)'
              || ' FROM misurazioni';

        -- determino la condizione della query
        IF dati_sensore.id_sensore = 0::smallint THEN
        
            query = query || ' INNER JOIN sensori ON (misurazioni.id_sensore = sensori.id_sensore)'
                          || ' WHERE data_ora >= $1 AND incluso_in_media = $2';
                        
            EXECUTE query
               INTO dati_sensore.temperatura_min,
                    dati_sensore.temperatura_med,
                    dati_sensore.temperatura_max,
                    dati_sensore.umidita_min,
                    dati_sensore.umidita_med,
                    dati_sensore.umidita_max
              USING NOW() - campione, true;

        ELSE

            query = query || ' WHERE data_ora >= $1 AND id_sensore = $2';
           
            EXECUTE query
               INTO dati_sensore.temperatura_min,
                    dati_sensore.temperatura_med,
                    dati_sensore.temperatura_max,
                    dati_sensore.umidita_min,
                    dati_sensore.umidita_med,
                    dati_sensore.umidita_max
              USING NOW() - campione, dati_sensore.id_sensore;

        END IF;
    
    END IF;

    RETURN NEXT dati_sensore;

END;
$_$;


ALTER FUNCTION public.dati_sensore(l_id_sensore smallint, campione interval, target interval) OWNER TO smac;

--
-- Name: dbg_genera_misurazioni(date, date); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION dbg_genera_misurazioni(data_iniziale date DEFAULT now(), data_finale date DEFAULT now()) RETURNS void
    LANGUAGE plpgsql
    AS $$DECLARE
    start_campione timestamp without time zone;
    end_campione timestamp without time zone;
    sensori smallint[];
    id_sens smallint;
    temp numeric(9,4);
    humy numeric(9,4);
   
BEGIN
    start_campione = data_iniziale + '00:00:00'::interval;
    end_campione = data_finale +'24:00:00'::interval;

    select array(select id_sensore from sensori) into sensori;

    LOOP

        FOREACH id_sens IN ARRAY sensori LOOP

            temp = (((RANDOM() * 10000)::integer % 400) - 100)::decimal(9,4) / 10::decimal(9,4);
            humy = (((RANDOM() * 100)::integer % 40) + 40);

            INSERT INTO misurazioni(data_ora, id_sensore, temperatura, umidita)
                 VALUES (start_campione, id_sens, temp, humy);
        END LOOP;

        start_campione = start_campione + '1 minute'::interval;
        
        EXIT WHEN start_campione >= end_campione;
   END LOOP;
END;$$;


ALTER FUNCTION public.dbg_genera_misurazioni(data_iniziale date, data_finale date) OWNER TO smac;

--
-- Name: dettagli_sensore(smallint); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION dettagli_sensore(l_id_sensore smallint DEFAULT NULL::smallint) RETURNS SETOF parametri_sensore
    LANGUAGE plpgsql ROWS 1
    AS $$
BEGIN
    -- @ valore assoluto
    l_id_sensore = @ COALESCE(l_id_sensore, 0);

    IF l_id_sensore = 0 THEN

        -- ottengo i valori medi attuali
        RETURN QUERY SELECT
               0::smallint,
               get_setting('sensore_media_nome'::varchar(64),'Media'::text)::Varchar(64),
               get_setting('sensore_media_nome'::varchar(64),'Media'::text)::Varchar(254),
               null::point,
               true,
               false,
               null::smallint,
               null::varchar(16),
               null::varchar(64);
    ELSE RETURN QUERY
        SELECT id_sensore,
               nome_sensore,
               descrizione,
               posizione,
               abilitato,
               incluso_in_media,
               s.id_driver,
               d.nome_driver,
               d.parametri_driver
          FROM sensori AS s
     LEFT JOIN driver_sensori AS d
            ON (s.id_driver = d.id_driver)
         WHERE s.id_sensore = l_id_sensore;
    END IF;
END;
$$;


ALTER FUNCTION public.dettagli_sensore(l_id_sensore smallint) OWNER TO smac;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: programmi; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE programmi (
    id_programma integer NOT NULL,
    nome_programma character varying(64) NOT NULL,
    descrizione_programma text,
    temperature_rif numeric(9,4)[] DEFAULT '{NULL,NULL,NULL,NULL,NULL}'::numeric[],
    sensore_rif smallint DEFAULT 0 NOT NULL
);


ALTER TABLE programmi OWNER TO smac;

--
-- Name: elenco_programmi(); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION elenco_programmi() RETURNS SETOF programmi
    LANGUAGE plpgsql
    AS $$

BEGIN

    RETURN QUERY SELECT  id_programma, nome_programma::varchar(64), descrizione_programma, temperature_rif::numeric(9,4)[], sensore_rif FROM dati_programma(-1::smallint);
    RETURN QUERY SELECT  id_programma, nome_programma::varchar(64), descrizione_programma, temperature_rif::numeric(9,4)[], sensore_rif FROM dati_programma(0::smallint);
    RETURN QUERY SELECT * FROM programmi ORDER BY nome_programma;
    RETURN QUERY SELECT  id_programma, nome_programma::varchar(64), descrizione_programma, temperature_rif::numeric(9,4)[], sensore_rif FROM dati_programma(32767::smallint);
    RETURN;
       
END$$;


ALTER FUNCTION public.elenco_programmi() OWNER TO smac;

--
-- Name: sensori; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE sensori (
    id_sensore smallint NOT NULL,
    nome_sensore character varying(64),
    descrizione character varying(256),
    posizione point,
    abilitato boolean DEFAULT true NOT NULL,
    incluso_in_media boolean DEFAULT false,
    id_driver smallint,
    ultimo_aggiornamento timestamp without time zone
);


ALTER TABLE sensori OWNER TO smac;

--
-- Name: TABLE sensori; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON TABLE sensori IS 'elenco dei sensori usati';


--
-- Name: COLUMN sensori.ultimo_aggiornamento; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON COLUMN sensori.ultimo_aggiornamento IS 'Data e ora dell''ultimo aggiornamento delle previsioni delle misurazioni';


--
-- Name: elenco_sensori(boolean); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION elenco_sensori(stato boolean DEFAULT NULL::boolean) RETURNS SETOF sensori
    LANGUAGE plpgsql ROWS 100
    AS $$

DECLARE
   queryAll BOOLEAN;
   statoMedia BOOLEAN;
BEGIN
    -- stato = t solo abilitati, stato = f solo disattivi, stato = null, tutti i sensori
    queryAll = stato IS UNKNOWN;

    -- Determino se la media è un sensore attivo o meno - cioè se ci sono sensori inclusi o meno

    SELECT COUNT(id_sensore) > 0 FROM public.sensori INTO statoMedia WHERE incluso_in_media = true;

    IF queryAll OR ( stato = statoMedia ) THEN

        RETURN QUERY
            SELECT 0::smallint,
                   get_setting('sensore_media_nome'::varchar(64),'Media'::text)::Varchar(64),
                   get_setting('sensore_media_descrizione'::varchar(64),'Media'::text)::Varchar(256),
                   NULL::Point,
                   statoMedia,
                   NULL::boolean,
                   NULL::smallint,
                   NOW()::Timestamp Without Time Zone;
     END IF;

     RETURN QUERY
           SELECT *
             FROM sensori
            WHERE queryAll
               OR abilitato = stato
         ORDER BY incluso_in_media DESC, nome_sensore ASC;
    RETURN;

END$$;


ALTER FUNCTION public.elenco_sensori(stato boolean) OWNER TO smac;

--
-- Name: elimina_programma(integer); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION elimina_programma(progr_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN

   DELETE FROM dettaglio_programma WHERE id_programma = progr_id;
   DELETE FROM programmi WHERE id_programma = progr_id;
   -- eventualmente metto il sistema in anticongelamento
   IF ( progr_id = get_setting('programma_attuale'::varchar,'-1'::text)::integer ) THEN
      PERFORM set_setting('programma_attuale'::varchar, '0'::text);
   END IF;
END$$;


ALTER FUNCTION public.elimina_programma(progr_id integer) OWNER TO smac;

--
-- Name: esiste_programma(integer); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION esiste_programma(progr_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

BEGIN
 RETURN EXISTS(
    SELECT id_programma FROM elenco_programmi() WHERE id_programma = progr_id
 );
END$$;


ALTER FUNCTION public.esiste_programma(progr_id integer) OWNER TO smac;

--
-- Name: esiste_sensore(smallint, boolean); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION esiste_sensore(sens_id smallint, stato boolean DEFAULT true) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

BEGIN
 RETURN EXISTS(
    SELECT id_sensore FROM elenco_sensori(stato) WHERE id_sensore = sens_id
 );
END$$;


ALTER FUNCTION public.esiste_sensore(sens_id smallint, stato boolean) OWNER TO smac;

--
-- Name: get_setting(character varying, text); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION get_setting(in_nome character varying, predef text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    val text;
BEGIN
	SELECT valore INTO val FROM impostazioni WHERE nome = in_nome;
	RETURN COALESCE(val, predef);
END;$$;


ALTER FUNCTION public.get_setting(in_nome character varying, predef text) OWNER TO smac;

--
-- Name: previsione_mq(smallint, character varying, interval, interval); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION previsione_mq(sensore smallint, grandezza character varying, campione interval DEFAULT '01:00:00'::interval, target interval DEFAULT '00:10:00'::interval) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$DECLARE
	media_date integer DEFAULT 0;
	media_valori numeric DEFAULT 0.0;
	scarto numeric DEFAULT 0.0;
	scarto_quadratico numeric DEFAULT 0.0;
	coeff_angolare numeric DEFAULT 0.0;
	termine_noto numeric DEFAULT 0.0;
BEGIN
	-- Muting errors
	SET LOCAL client_min_messages TO WARNING;

    -- Creating temp table to store values
	DROP TABLE IF EXISTS campioni;
	CREATE TEMPORARY TABLE campioni(
		epoch_date bigint,
		valore numeric(9,4)
	);

    -- Insert  last grandezza value into temp table
    EXECUTE format('
        INSERT INTO campioni
             SELECT EXTRACT(EPOCH FROM data_ora), %I
               FROM misurazioni
              WHERE data_ora >= ( now() - $1 )
                AND id_sensore = $2
                AND %I IS NOT NULL;',
        grandezza,
        grandezza
    ) USING campione, sensore;

	
    -- Calcolod i valori medi per tempi e valori
	SELECT AVG(epoch_date), AVG(valore) INTO media_date, media_valori FROM campioni;

	-- Estraggo la sommatoria delle differenze e differenze quadratiche
	SELECT SUM( ( epoch_date - media_date ) * ( valore - media_valori )),
	       SUM( ( epoch_date - media_date ) ^ 2 )
	  INTO scarto, scarto_quadratico
	  FROM campioni;

	coeff_angolare = scarto / scarto_quadratico;
	termine_noto = media_valori  - coeff_angolare * media_date;

	DROP TABLE campioni;

	return coeff_angolare * EXTRACT(EPOCH FROM (NOW() + target)) + termine_noto;

END$_$;


ALTER FUNCTION public.previsione_mq(sensore smallint, grandezza character varying, campione interval, target interval) OWNER TO smac;

--
-- Name: programmazioni(integer, smallint); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION programmazioni(progr_id integer DEFAULT NULL::integer, prog_giorno smallint DEFAULT NULL::smallint) RETURNS TABLE(id_programma integer, giorno smallint, ora time without time zone, intervallo integer, t_rif_indice smallint, t_rif_val numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    t_rif smallint DEFAULT 1;
    t_val NUMERIC(9,4) DEFAULT null;
    g_rif_min smallint DEFAULT 1;
    g_rif_max smallint DEFAULT 7;

BEGIN

    IF progr_id IS NULL THEN
       progr_id = get_setting('programma_attuale'::varchar,'-1'::text);
    END IF;

    -- if prog_giorno == 0 retrieve all day
    IF prog_giorno >= 1 AND prog_giorno <= 7 THEN
       g_rif_min = prog_giorno;
       g_rif_max = prog_giorno;
    ELSIF prog_giorno IS NULL THEN
       g_rif_min = date_part('ISODOW', NOW());
       g_rif_max = g_rif_min;
    END IF;

    CASE progr_id::smallint
    
	-- sistema spento o anticongelamento o manuale 
        WHEN -1, 0, 32767 THEN

            -- t_rif = null solo per spento
	    CASE progr_id::smallint
	        WHEN -1 THEN t_rif = null;
	        WHEN 0 THEN t_val = get_setting('temperatura_anticongelamento'::varchar,'5'::text);
	        WHEN  32767 THEN t_val = get_setting('temperatura_manuale'::varchar,'20'::text);
	     END CASE;

            WHILE g_rif_min <= g_rif_max LOOP
                RETURN QUERY
                    SELECT progr_id,
                           g_rif_min,
                           (h || ':00')::time,
                           EXTRACT(EPOCH FROM (h || ':00')::time)::integer,
                           t_rif::smallint, t_val
                      FROM generate_series(0,23, 12) AS h;

	        g_rif_min = g_rif_min + 1;
	    END LOOP;

        -- richiesta specifico dettaglio
	ELSE
	    RETURN QUERY SELECT d.id_programma,
                                d.giorno,
                                d.ora,
                                EXTRACT(EPOCH FROM d.ora)::integer,
                                
                                CASE WHEN d.t_riferimento IS NULL OR d.t_riferimento = 0 THEN 1::smallint
                                     ELSE d.t_riferimento
                                END,
                                CASE WHEN d.t_riferimento IS NULL OR d.t_riferimento = 0 THEN p.temperature_rif[1]
                                     ELSE p.temperature_rif[d.t_riferimento]
                                END
                           FROM dettaglio_programma AS d
                      LEFT JOIN programmi AS p
                             ON p.id_programma = d.id_programma
                          WHERE d.id_programma = progr_id
                            AND d.giorno BETWEEN g_rif_min AND g_rif_max ORDER BY d.giorno, d.ora;
        END CASE;

        RETURN;
END$$;


ALTER FUNCTION public.programmazioni(progr_id integer, prog_giorno smallint) OWNER TO smac;

--
-- Name: report_misurazioni(smallint, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION report_misurazioni(pid_sensore smallint, data_ora_inizio timestamp without time zone DEFAULT (now() - '01:00:00'::interval), data_ora_fine timestamp without time zone DEFAULT now()) RETURNS SETOF report_sensore
    LANGUAGE plpgsql
    AS $$DECLARE
BEGIN
    -- se null o 0 si tratta della media
    IF pid_sensore IS NULL OR pid_sensore = 0  THEN
        RETURN QUERY
            SELECT date_trunc('minute', misurazioni.data_ora) as tr_data_ora,
                   0::smallint,
                   'Media'::varchar,
                   AVG(misurazioni.temperatura)::numeric(9,4),
                   AVG(misurazioni.umidita)::numeric(9,4)
              FROM misurazioni
        INNER JOIN sensori
                ON (sensori.id_sensore = misurazioni.id_sensore)
             WHERE sensori.incluso_in_media = true
               AND misurazioni.data_ora BETWEEN data_ora_inizio AND data_ora_fine
          GROUP BY tr_data_ora
          ORDER BY tr_data_ora;
    ELSE
        RETURN QUERY
            SELECT misurazioni.data_ora,
                   misurazioni.id_sensore,
                   sensori.nome_sensore,
                   misurazioni.temperatura,
                   misurazioni.umidita
              FROM misurazioni
        INNER JOIN sensori
                ON (sensori.id_sensore = misurazioni.id_sensore)
             WHERE misurazioni.data_ora BETWEEN data_ora_inizio AND data_ora_fine
               AND misurazioni.id_sensore = pid_sensore
          ORDER BY misurazioni.data_ora;
    END IF;

END;$$;


ALTER FUNCTION public.report_misurazioni(pid_sensore smallint, data_ora_inizio timestamp without time zone, data_ora_fine timestamp without time zone) OWNER TO smac;

--
-- Name: set_setting(character varying, text); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION set_setting(in_nome character varying, in_val text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	c_nome character varying;
BEGIN
	SELECT nome INTO c_nome FROM impostazioni WHERE nome = in_nome;

	IF c_nome IS NOT NULL THEN
		UPDATE impostazioni SET valore = in_val WHERE nome = in_nome;
	ELSE
	   INSERT INTO impostazioni(nome, valore) VALUES(in_nome, in_val);
	END IF;
END;$$;


ALTER FUNCTION public.set_setting(in_nome character varying, in_val text) OWNER TO smac;

--
-- Name: dati_giornalieri; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE dati_giornalieri (
    data date NOT NULL,
    id_sensore smallint NOT NULL,
    id_synop_temp_min bigint,
    id_synop_temp_max bigint,
    id_syrep_temp_min bigint,
    id_syrep_temp_max bigint,
    id_umidita_min bigint,
    id_umidita_max bigint
);


ALTER TABLE dati_giornalieri OWNER TO smac;

--
-- Name: dettaglio_programma; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE dettaglio_programma (
    id_programma integer NOT NULL,
    giorno smallint NOT NULL,
    ora time without time zone NOT NULL,
    t_riferimento smallint
);


ALTER TABLE dettaglio_programma OWNER TO smac;

--
-- Name: driver_sensori; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE driver_sensori (
    id_driver smallint NOT NULL,
    nome_driver character varying(16),
    parametri_driver character varying(64)
);


ALTER TABLE driver_sensori OWNER TO smac;

--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE driver_sensori_id_driver_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE driver_sensori_id_driver_seq OWNER TO smac;

--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE driver_sensori_id_driver_seq OWNED BY driver_sensori.id_driver;


--
-- Name: impostazioni; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE impostazioni (
    nome character varying(128) NOT NULL,
    valore text
);


ALTER TABLE impostazioni OWNER TO smac;

--
-- Name: COLUMN impostazioni.nome; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON COLUMN impostazioni.nome IS 'Nome della voce di impostazione';


--
-- Name: COLUMN impostazioni.valore; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON COLUMN impostazioni.valore IS 'Valore della voce di impostazione';


--
-- Name: misurazioni; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE misurazioni (
    id_misurazione bigint NOT NULL,
    data_ora timestamp without time zone DEFAULT now() NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4)
);


ALTER TABLE misurazioni OWNER TO smac;

--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE misurazioni_id_misurazione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE misurazioni_id_misurazione_seq OWNER TO smac;

--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE misurazioni_id_misurazione_seq OWNED BY misurazioni.id_misurazione;


--
-- Name: programma_id_programma_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE programma_id_programma_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE programma_id_programma_seq OWNER TO smac;

--
-- Name: programma_id_programma_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE programma_id_programma_seq OWNED BY programmi.id_programma;


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE sensori_id_sensore_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE sensori_id_sensore_seq OWNER TO smac;

--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE sensori_id_sensore_seq OWNED BY sensori.id_sensore;


--
-- Name: situazione; Type: TABLE; Schema: public; Owner: smac
--

CREATE TABLE situazione (
    data_ora timestamp without time zone NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4),
    tendenza_temperatura numeric(9,4),
    tendenza_umidita numeric(9,4)
);


ALTER TABLE situazione OWNER TO smac;

--
-- Name: id_driver; Type: DEFAULT; Schema: public; Owner: smac
--

ALTER TABLE ONLY driver_sensori ALTER COLUMN id_driver SET DEFAULT nextval('driver_sensori_id_driver_seq'::regclass);


--
-- Name: id_misurazione; Type: DEFAULT; Schema: public; Owner: smac
--

ALTER TABLE ONLY misurazioni ALTER COLUMN id_misurazione SET DEFAULT nextval('misurazioni_id_misurazione_seq'::regclass);


--
-- Name: id_programma; Type: DEFAULT; Schema: public; Owner: smac
--

ALTER TABLE ONLY programmi ALTER COLUMN id_programma SET DEFAULT nextval('programma_id_programma_seq'::regclass);


--
-- Name: id_sensore; Type: DEFAULT; Schema: public; Owner: smac
--

ALTER TABLE ONLY sensori ALTER COLUMN id_sensore SET DEFAULT nextval('sensori_id_sensore_seq'::regclass);


--
-- Data for Name: dati_giornalieri; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY dati_giornalieri (data, id_sensore, id_synop_temp_min, id_synop_temp_max, id_syrep_temp_min, id_syrep_temp_max, id_umidita_min, id_umidita_max) FROM stdin;
\.


--
-- Data for Name: dettaglio_programma; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY dettaglio_programma (id_programma, giorno, ora, t_riferimento) FROM stdin;
31	3	17:00:00	2
31	3	17:30:00	3
31	3	18:30:00	4
31	3	20:00:00	1
31	4	00:00:00	1
31	4	05:00:00	2
31	4	06:00:00	4
31	4	08:00:00	1
31	4	17:00:00	2
31	4	17:30:00	3
31	4	18:30:00	4
31	4	20:00:00	1
31	5	00:00:00	1
31	5	05:00:00	2
31	5	06:00:00	4
31	5	08:00:00	1
31	5	17:00:00	2
31	5	17:30:00	3
31	5	18:30:00	4
31	5	20:00:00	1
31	6	00:00:00	1
31	6	18:30:00	4
31	6	20:00:00	1
31	6	10:30:00	1
31	6	08:00:00	4
31	7	00:00:00	1
31	7	08:00:00	4
31	7	10:30:00	1
31	7	18:30:00	4
31	7	20:00:00	1
31	1	00:00:00	1
31	1	05:00:00	2
31	1	06:00:00	4
31	1	08:00:00	1
31	1	17:00:00	2
31	1	17:30:00	3
31	1	18:30:00	4
31	1	20:00:00	1
31	2	00:00:00	1
31	2	05:00:00	2
31	2	06:00:00	4
31	2	08:00:00	1
31	2	17:00:00	2
31	2	17:30:00	3
31	2	18:30:00	4
31	2	20:00:00	1
31	3	00:00:00	1
31	3	05:00:00	2
31	3	06:00:00	4
31	3	08:00:00	1
\.


--
-- Data for Name: driver_sensori; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY driver_sensori (id_driver, nome_driver, parametri_driver) FROM stdin;
1	DHT11	\N
\.


--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('driver_sensori_id_driver_seq', 1, true);


--
-- Data for Name: impostazioni; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY impostazioni (nome, valore) FROM stdin;
programma_attuale	31
programma_spento_nome	Spento
programma_spento_descrizione	Il sistema rimarrà sempre spento, indipendentemente dalle temperature registrate
programma_anticongelamento_nome	Anticongelamento
programma_anticongelamento_descrizione	Il sistema si accenderà solo per evitare il congelamento. Cioè quando la temperatura ambientale scenderà al di sotto di quella rilevata da sensore di anticongelamento
programma_anticongelamento_sensore	0
programma_manuale_nome	Manuale
programma_manuale_descrizione	Il sistema proverà a mantenere la temperatura impostata manualmente
programma_manuale_sensore	0
temperatura_anticongelamento	5
temperatura_manuale	20
\.


--
-- Data for Name: misurazioni; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY misurazioni (id_misurazione, data_ora, id_sensore, temperatura, umidita) FROM stdin;
1	2016-03-21 00:00:00	1	24.1000	46.0000
2	2016-03-21 00:01:00	1	12.3000	43.0000
3	2016-03-21 00:02:00	1	-5.8000	43.0000
4	2016-03-21 00:03:00	1	24.2000	76.0000
5	2016-03-21 00:04:00	1	22.8000	70.0000
6	2016-03-21 00:05:00	1	3.9000	78.0000
7	2016-03-21 00:06:00	1	-3.9000	50.0000
8	2016-03-21 00:07:00	1	-3.1000	60.0000
9	2016-03-21 00:08:00	1	-6.8000	40.0000
10	2016-03-21 00:09:00	1	11.2000	46.0000
11	2016-03-21 00:10:00	1	21.9000	56.0000
12	2016-03-21 00:11:00	1	16.3000	45.0000
13	2016-03-21 00:12:00	1	13.9000	46.0000
14	2016-03-21 00:13:00	1	-8.9000	59.0000
15	2016-03-21 00:14:00	1	14.7000	56.0000
16	2016-03-21 00:15:00	1	23.5000	46.0000
17	2016-03-21 00:16:00	1	14.7000	62.0000
18	2016-03-21 00:17:00	1	0.2000	67.0000
19	2016-03-21 00:18:00	1	-0.8000	52.0000
20	2016-03-21 00:19:00	1	21.3000	56.0000
21	2016-03-21 00:20:00	1	18.0000	69.0000
22	2016-03-21 00:21:00	1	11.8000	43.0000
23	2016-03-21 00:22:00	1	14.6000	67.0000
24	2016-03-21 00:23:00	1	22.3000	43.0000
25	2016-03-21 00:24:00	1	19.1000	77.0000
26	2016-03-21 00:25:00	1	-0.1000	78.0000
27	2016-03-21 00:26:00	1	-0.4000	56.0000
28	2016-03-21 00:27:00	1	24.7000	51.0000
29	2016-03-21 00:28:00	1	1.4000	52.0000
30	2016-03-21 00:29:00	1	14.5000	68.0000
31	2016-03-21 00:30:00	1	-9.9000	58.0000
32	2016-03-21 00:31:00	1	5.0000	70.0000
33	2016-03-21 00:32:00	1	23.7000	43.0000
34	2016-03-21 00:33:00	1	3.8000	44.0000
35	2016-03-21 00:34:00	1	19.6000	41.0000
36	2016-03-21 00:35:00	1	-5.2000	78.0000
37	2016-03-21 00:36:00	1	0.2000	55.0000
38	2016-03-21 00:37:00	1	1.6000	67.0000
39	2016-03-21 00:38:00	1	5.4000	44.0000
40	2016-03-21 00:39:00	1	12.6000	68.0000
41	2016-03-21 00:40:00	1	7.3000	79.0000
42	2016-03-21 00:41:00	1	15.5000	55.0000
43	2016-03-21 00:42:00	1	18.8000	50.0000
44	2016-03-21 00:43:00	1	10.4000	56.0000
45	2016-03-21 00:44:00	1	6.0000	56.0000
46	2016-03-21 00:45:00	1	26.3000	50.0000
47	2016-03-21 00:46:00	1	12.9000	57.0000
48	2016-03-21 00:47:00	1	-9.0000	54.0000
49	2016-03-21 00:48:00	1	26.5000	57.0000
50	2016-03-21 00:49:00	1	9.4000	55.0000
51	2016-03-21 00:50:00	1	9.8000	78.0000
52	2016-03-21 00:51:00	1	-6.4000	47.0000
53	2016-03-21 00:52:00	1	0.8000	74.0000
54	2016-03-21 00:53:00	1	14.9000	75.0000
55	2016-03-21 00:54:00	1	9.0000	45.0000
56	2016-03-21 00:55:00	1	20.6000	60.0000
57	2016-03-21 00:56:00	1	-9.9000	70.0000
58	2016-03-21 00:57:00	1	13.3000	79.0000
59	2016-03-21 00:58:00	1	26.2000	60.0000
60	2016-03-21 00:59:00	1	19.0000	61.0000
61	2016-03-21 01:00:00	1	-1.5000	79.0000
62	2016-03-21 01:01:00	1	18.3000	51.0000
63	2016-03-21 01:02:00	1	26.7000	51.0000
64	2016-03-21 01:03:00	1	-2.1000	55.0000
65	2016-03-21 01:04:00	1	-5.9000	43.0000
66	2016-03-21 01:05:00	1	9.3000	66.0000
67	2016-03-21 01:06:00	1	1.5000	62.0000
68	2016-03-21 01:07:00	1	4.0000	74.0000
69	2016-03-21 01:08:00	1	28.0000	48.0000
70	2016-03-21 01:09:00	1	-1.5000	74.0000
71	2016-03-21 01:10:00	1	-3.6000	72.0000
72	2016-03-21 01:11:00	1	3.4000	77.0000
73	2016-03-21 01:12:00	1	5.2000	48.0000
74	2016-03-21 01:13:00	1	25.3000	41.0000
75	2016-03-21 01:14:00	1	-9.7000	70.0000
76	2016-03-21 01:15:00	1	13.7000	45.0000
77	2016-03-21 01:16:00	1	-0.3000	53.0000
78	2016-03-21 01:17:00	1	-9.8000	45.0000
79	2016-03-21 01:18:00	1	-8.7000	61.0000
80	2016-03-21 01:19:00	1	29.6000	73.0000
81	2016-03-21 01:20:00	1	25.4000	70.0000
82	2016-03-21 01:21:00	1	19.3000	65.0000
83	2016-03-21 01:22:00	1	-8.2000	52.0000
84	2016-03-21 01:23:00	1	19.3000	48.0000
85	2016-03-21 01:24:00	1	-7.9000	68.0000
86	2016-03-21 01:25:00	1	6.9000	73.0000
87	2016-03-21 01:26:00	1	26.9000	55.0000
88	2016-03-21 01:27:00	1	5.0000	61.0000
89	2016-03-21 01:28:00	1	16.9000	45.0000
90	2016-03-21 01:29:00	1	13.6000	51.0000
91	2016-03-21 01:30:00	1	24.5000	45.0000
92	2016-03-21 01:31:00	1	25.9000	44.0000
93	2016-03-21 01:32:00	1	9.3000	72.0000
94	2016-03-21 01:33:00	1	0.6000	62.0000
95	2016-03-21 01:34:00	1	-5.8000	49.0000
96	2016-03-21 01:35:00	1	16.1000	56.0000
97	2016-03-21 01:36:00	1	19.2000	54.0000
98	2016-03-21 01:37:00	1	-3.4000	51.0000
99	2016-03-21 01:38:00	1	8.7000	60.0000
100	2016-03-21 01:39:00	1	20.8000	46.0000
101	2016-03-21 01:40:00	1	23.6000	61.0000
102	2016-03-21 01:41:00	1	19.4000	47.0000
103	2016-03-21 01:42:00	1	27.9000	48.0000
104	2016-03-21 01:43:00	1	-7.3000	58.0000
105	2016-03-21 01:44:00	1	4.6000	51.0000
106	2016-03-21 01:45:00	1	2.0000	69.0000
107	2016-03-21 01:46:00	1	23.6000	65.0000
108	2016-03-21 01:47:00	1	3.3000	73.0000
109	2016-03-21 01:48:00	1	-6.0000	42.0000
110	2016-03-21 01:49:00	1	23.6000	49.0000
111	2016-03-21 01:50:00	1	24.2000	70.0000
112	2016-03-21 01:51:00	1	-2.2000	50.0000
113	2016-03-21 01:52:00	1	25.1000	45.0000
114	2016-03-21 01:53:00	1	4.3000	69.0000
115	2016-03-21 01:54:00	1	0.2000	61.0000
116	2016-03-21 01:55:00	1	24.7000	52.0000
117	2016-03-21 01:56:00	1	2.8000	54.0000
118	2016-03-21 01:57:00	1	24.3000	77.0000
119	2016-03-21 01:58:00	1	18.3000	68.0000
120	2016-03-21 01:59:00	1	25.6000	76.0000
121	2016-03-21 02:00:00	1	13.2000	45.0000
122	2016-03-21 02:01:00	1	2.0000	54.0000
123	2016-03-21 02:02:00	1	5.4000	79.0000
124	2016-03-21 02:03:00	1	19.8000	66.0000
125	2016-03-21 02:04:00	1	-0.7000	42.0000
126	2016-03-21 02:05:00	1	17.6000	52.0000
127	2016-03-21 02:06:00	1	-6.9000	40.0000
128	2016-03-21 02:07:00	1	16.8000	56.0000
129	2016-03-21 02:08:00	1	-0.2000	64.0000
130	2016-03-21 02:09:00	1	2.1000	70.0000
131	2016-03-21 02:10:00	1	-3.8000	61.0000
132	2016-03-21 02:11:00	1	13.8000	46.0000
133	2016-03-21 02:12:00	1	20.7000	42.0000
134	2016-03-21 02:13:00	1	19.7000	78.0000
135	2016-03-21 02:14:00	1	5.0000	59.0000
136	2016-03-21 02:15:00	1	12.0000	48.0000
137	2016-03-21 02:16:00	1	22.8000	59.0000
138	2016-03-21 02:17:00	1	5.1000	53.0000
139	2016-03-21 02:18:00	1	9.4000	48.0000
140	2016-03-21 02:19:00	1	17.7000	79.0000
141	2016-03-21 02:20:00	1	18.3000	74.0000
142	2016-03-21 02:21:00	1	22.1000	43.0000
143	2016-03-21 02:22:00	1	0.7000	74.0000
144	2016-03-21 02:23:00	1	19.7000	58.0000
145	2016-03-21 02:24:00	1	10.0000	44.0000
146	2016-03-21 02:25:00	1	-9.4000	63.0000
147	2016-03-21 02:26:00	1	-1.5000	50.0000
148	2016-03-21 02:27:00	1	-4.8000	40.0000
149	2016-03-21 02:28:00	1	-7.5000	51.0000
150	2016-03-21 02:29:00	1	8.3000	42.0000
151	2016-03-21 02:30:00	1	10.2000	52.0000
152	2016-03-21 02:31:00	1	5.8000	73.0000
153	2016-03-21 02:32:00	1	24.3000	71.0000
154	2016-03-21 02:33:00	1	11.3000	69.0000
155	2016-03-21 02:34:00	1	25.8000	65.0000
156	2016-03-21 02:35:00	1	-7.8000	50.0000
157	2016-03-21 02:36:00	1	14.2000	79.0000
158	2016-03-21 02:37:00	1	5.6000	71.0000
159	2016-03-21 02:38:00	1	3.2000	73.0000
160	2016-03-21 02:39:00	1	5.5000	51.0000
161	2016-03-21 02:40:00	1	-3.0000	58.0000
162	2016-03-21 02:41:00	1	9.4000	62.0000
163	2016-03-21 02:42:00	1	-9.5000	42.0000
164	2016-03-21 02:43:00	1	4.6000	60.0000
165	2016-03-21 02:44:00	1	9.4000	79.0000
166	2016-03-21 02:45:00	1	10.5000	44.0000
167	2016-03-21 02:46:00	1	23.2000	72.0000
168	2016-03-21 02:47:00	1	2.7000	43.0000
169	2016-03-21 02:48:00	1	17.1000	63.0000
170	2016-03-21 02:49:00	1	-9.0000	62.0000
171	2016-03-21 02:50:00	1	-7.1000	60.0000
172	2016-03-21 02:51:00	1	-3.0000	47.0000
173	2016-03-21 02:52:00	1	27.6000	46.0000
174	2016-03-21 02:53:00	1	12.1000	53.0000
175	2016-03-21 02:54:00	1	17.9000	68.0000
176	2016-03-21 02:55:00	1	-6.0000	55.0000
177	2016-03-21 02:56:00	1	3.6000	58.0000
178	2016-03-21 02:57:00	1	0.4000	73.0000
179	2016-03-21 02:58:00	1	-2.1000	79.0000
180	2016-03-21 02:59:00	1	7.0000	55.0000
181	2016-03-21 03:00:00	1	7.9000	76.0000
182	2016-03-21 03:01:00	1	17.0000	49.0000
183	2016-03-21 03:02:00	1	23.7000	76.0000
184	2016-03-21 03:03:00	1	28.5000	50.0000
185	2016-03-21 03:04:00	1	23.7000	44.0000
186	2016-03-21 03:05:00	1	-6.2000	48.0000
187	2016-03-21 03:06:00	1	-7.2000	45.0000
188	2016-03-21 03:07:00	1	13.7000	44.0000
189	2016-03-21 03:08:00	1	23.4000	53.0000
190	2016-03-21 03:09:00	1	1.2000	50.0000
191	2016-03-21 03:10:00	1	-6.7000	62.0000
192	2016-03-21 03:11:00	1	6.2000	46.0000
193	2016-03-21 03:12:00	1	28.6000	63.0000
194	2016-03-21 03:13:00	1	21.0000	61.0000
195	2016-03-21 03:14:00	1	1.6000	73.0000
196	2016-03-21 03:15:00	1	24.0000	59.0000
197	2016-03-21 03:16:00	1	-4.5000	54.0000
198	2016-03-21 03:17:00	1	-9.4000	56.0000
199	2016-03-21 03:18:00	1	10.7000	60.0000
200	2016-03-21 03:19:00	1	10.1000	49.0000
201	2016-03-21 03:20:00	1	28.5000	78.0000
202	2016-03-21 03:21:00	1	0.9000	68.0000
203	2016-03-21 03:22:00	1	24.6000	51.0000
204	2016-03-21 03:23:00	1	-8.3000	55.0000
205	2016-03-21 03:24:00	1	-9.7000	49.0000
206	2016-03-21 03:25:00	1	-0.7000	44.0000
207	2016-03-21 03:26:00	1	18.1000	71.0000
208	2016-03-21 03:27:00	1	10.5000	71.0000
209	2016-03-21 03:28:00	1	2.1000	49.0000
210	2016-03-21 03:29:00	1	23.3000	54.0000
211	2016-03-21 03:30:00	1	9.6000	67.0000
212	2016-03-21 03:31:00	1	3.1000	51.0000
213	2016-03-21 03:32:00	1	-1.7000	41.0000
214	2016-03-21 03:33:00	1	14.4000	51.0000
215	2016-03-21 03:34:00	1	2.7000	72.0000
216	2016-03-21 03:35:00	1	-6.7000	45.0000
217	2016-03-21 03:36:00	1	18.3000	77.0000
218	2016-03-21 03:37:00	1	2.5000	74.0000
219	2016-03-21 03:38:00	1	-1.1000	65.0000
220	2016-03-21 03:39:00	1	1.0000	53.0000
221	2016-03-21 03:40:00	1	17.1000	54.0000
222	2016-03-21 03:41:00	1	2.8000	66.0000
223	2016-03-21 03:42:00	1	-4.1000	67.0000
224	2016-03-21 03:43:00	1	-8.1000	58.0000
225	2016-03-21 03:44:00	1	-5.1000	48.0000
226	2016-03-21 03:45:00	1	-8.4000	58.0000
227	2016-03-21 03:46:00	1	12.6000	65.0000
228	2016-03-21 03:47:00	1	-0.3000	75.0000
229	2016-03-21 03:48:00	1	18.4000	55.0000
230	2016-03-21 03:49:00	1	9.8000	48.0000
231	2016-03-21 03:50:00	1	28.6000	46.0000
232	2016-03-21 03:51:00	1	2.4000	79.0000
233	2016-03-21 03:52:00	1	27.4000	46.0000
234	2016-03-21 03:53:00	1	0.0000	53.0000
235	2016-03-21 03:54:00	1	29.1000	62.0000
236	2016-03-21 03:55:00	1	5.5000	47.0000
237	2016-03-21 03:56:00	1	-8.6000	43.0000
238	2016-03-21 03:57:00	1	-8.6000	41.0000
239	2016-03-21 03:58:00	1	11.7000	68.0000
240	2016-03-21 03:59:00	1	15.3000	47.0000
241	2016-03-21 04:00:00	1	28.6000	71.0000
242	2016-03-21 04:01:00	1	1.2000	70.0000
243	2016-03-21 04:02:00	1	-8.3000	54.0000
244	2016-03-21 04:03:00	1	2.0000	43.0000
245	2016-03-21 04:04:00	1	5.1000	71.0000
246	2016-03-21 04:05:00	1	21.2000	77.0000
247	2016-03-21 04:06:00	1	4.9000	44.0000
248	2016-03-21 04:07:00	1	-9.3000	41.0000
249	2016-03-21 04:08:00	1	18.5000	49.0000
250	2016-03-21 04:09:00	1	8.6000	43.0000
251	2016-03-21 04:10:00	1	21.6000	59.0000
252	2016-03-21 04:11:00	1	3.9000	67.0000
253	2016-03-21 04:12:00	1	12.4000	62.0000
254	2016-03-21 04:13:00	1	-9.7000	52.0000
255	2016-03-21 04:14:00	1	8.5000	67.0000
256	2016-03-21 04:15:00	1	20.7000	46.0000
257	2016-03-21 04:16:00	1	2.4000	44.0000
258	2016-03-21 04:17:00	1	28.2000	53.0000
259	2016-03-21 04:18:00	1	12.8000	41.0000
260	2016-03-21 04:19:00	1	-5.8000	48.0000
261	2016-03-21 04:20:00	1	-8.0000	48.0000
262	2016-03-21 04:21:00	1	1.5000	70.0000
263	2016-03-21 04:22:00	1	29.0000	61.0000
264	2016-03-21 04:23:00	1	19.2000	43.0000
265	2016-03-21 04:24:00	1	12.8000	65.0000
266	2016-03-21 04:25:00	1	5.2000	41.0000
267	2016-03-21 04:26:00	1	-8.1000	75.0000
268	2016-03-21 04:27:00	1	-2.5000	66.0000
269	2016-03-21 04:28:00	1	-5.7000	77.0000
270	2016-03-21 04:29:00	1	18.3000	46.0000
271	2016-03-21 04:30:00	1	23.3000	58.0000
272	2016-03-21 04:31:00	1	29.9000	41.0000
273	2016-03-21 04:32:00	1	10.9000	48.0000
274	2016-03-21 04:33:00	1	9.8000	40.0000
275	2016-03-21 04:34:00	1	-1.7000	50.0000
276	2016-03-21 04:35:00	1	-8.5000	41.0000
277	2016-03-21 04:36:00	1	9.4000	53.0000
278	2016-03-21 04:37:00	1	17.2000	50.0000
279	2016-03-21 04:38:00	1	15.2000	42.0000
280	2016-03-21 04:39:00	1	-4.0000	45.0000
281	2016-03-21 04:40:00	1	14.2000	58.0000
282	2016-03-21 04:41:00	1	12.5000	51.0000
283	2016-03-21 04:42:00	1	0.4000	75.0000
284	2016-03-21 04:43:00	1	0.4000	49.0000
285	2016-03-21 04:44:00	1	27.7000	76.0000
286	2016-03-21 04:45:00	1	27.5000	55.0000
287	2016-03-21 04:46:00	1	7.7000	48.0000
288	2016-03-21 04:47:00	1	26.8000	76.0000
289	2016-03-21 04:48:00	1	25.6000	50.0000
290	2016-03-21 04:49:00	1	-7.8000	64.0000
291	2016-03-21 04:50:00	1	-9.4000	64.0000
292	2016-03-21 04:51:00	1	4.2000	78.0000
293	2016-03-21 04:52:00	1	6.6000	76.0000
294	2016-03-21 04:53:00	1	28.5000	72.0000
295	2016-03-21 04:54:00	1	7.7000	40.0000
296	2016-03-21 04:55:00	1	-0.2000	44.0000
297	2016-03-21 04:56:00	1	15.8000	63.0000
298	2016-03-21 04:57:00	1	18.0000	72.0000
299	2016-03-21 04:58:00	1	12.2000	72.0000
300	2016-03-21 04:59:00	1	0.9000	50.0000
301	2016-03-21 05:00:00	1	27.0000	77.0000
302	2016-03-21 05:01:00	1	1.0000	41.0000
303	2016-03-21 05:02:00	1	-4.1000	61.0000
304	2016-03-21 05:03:00	1	3.3000	40.0000
305	2016-03-21 05:04:00	1	14.3000	54.0000
306	2016-03-21 05:05:00	1	-4.6000	50.0000
307	2016-03-21 05:06:00	1	9.2000	70.0000
308	2016-03-21 05:07:00	1	-5.1000	56.0000
309	2016-03-21 05:08:00	1	10.9000	56.0000
310	2016-03-21 05:09:00	1	27.7000	44.0000
311	2016-03-21 05:10:00	1	-2.1000	45.0000
312	2016-03-21 05:11:00	1	-9.6000	55.0000
313	2016-03-21 05:12:00	1	29.7000	43.0000
314	2016-03-21 05:13:00	1	19.8000	66.0000
315	2016-03-21 05:14:00	1	16.7000	68.0000
316	2016-03-21 05:15:00	1	-8.1000	42.0000
317	2016-03-21 05:16:00	1	-0.9000	61.0000
318	2016-03-21 05:17:00	1	28.5000	50.0000
319	2016-03-21 05:18:00	1	10.7000	61.0000
320	2016-03-21 05:19:00	1	6.5000	52.0000
321	2016-03-21 05:20:00	1	17.3000	54.0000
322	2016-03-21 05:21:00	1	19.9000	73.0000
323	2016-03-21 05:22:00	1	-8.6000	71.0000
324	2016-03-21 05:23:00	1	-7.6000	50.0000
325	2016-03-21 05:24:00	1	28.2000	76.0000
326	2016-03-21 05:25:00	1	10.8000	65.0000
327	2016-03-21 05:26:00	1	-2.5000	42.0000
328	2016-03-21 05:27:00	1	29.7000	49.0000
329	2016-03-21 05:28:00	1	-0.4000	67.0000
330	2016-03-21 05:29:00	1	19.2000	60.0000
331	2016-03-21 05:30:00	1	20.3000	71.0000
332	2016-03-21 05:31:00	1	10.1000	40.0000
333	2016-03-21 05:32:00	1	-6.0000	46.0000
334	2016-03-21 05:33:00	1	4.4000	74.0000
335	2016-03-21 05:34:00	1	20.3000	79.0000
336	2016-03-21 05:35:00	1	19.7000	62.0000
337	2016-03-21 05:36:00	1	2.7000	50.0000
338	2016-03-21 05:37:00	1	14.2000	57.0000
339	2016-03-21 05:38:00	1	4.4000	43.0000
340	2016-03-21 05:39:00	1	26.3000	49.0000
341	2016-03-21 05:40:00	1	16.6000	62.0000
342	2016-03-21 05:41:00	1	8.7000	79.0000
343	2016-03-21 05:42:00	1	28.4000	54.0000
344	2016-03-21 05:43:00	1	-8.6000	69.0000
345	2016-03-21 05:44:00	1	-2.0000	63.0000
346	2016-03-21 05:45:00	1	-5.7000	56.0000
347	2016-03-21 05:46:00	1	11.7000	50.0000
348	2016-03-21 05:47:00	1	27.7000	47.0000
349	2016-03-21 05:48:00	1	-7.1000	65.0000
350	2016-03-21 05:49:00	1	0.4000	43.0000
351	2016-03-21 05:50:00	1	-7.0000	68.0000
352	2016-03-21 05:51:00	1	0.8000	78.0000
353	2016-03-21 05:52:00	1	9.7000	60.0000
354	2016-03-21 05:53:00	1	19.9000	59.0000
355	2016-03-21 05:54:00	1	11.6000	63.0000
356	2016-03-21 05:55:00	1	-3.3000	61.0000
357	2016-03-21 05:56:00	1	-6.6000	43.0000
358	2016-03-21 05:57:00	1	-7.7000	68.0000
359	2016-03-21 05:58:00	1	-6.2000	48.0000
360	2016-03-21 05:59:00	1	-0.3000	77.0000
361	2016-03-21 06:00:00	1	24.3000	65.0000
362	2016-03-21 06:01:00	1	0.1000	66.0000
363	2016-03-21 06:02:00	1	28.4000	69.0000
364	2016-03-21 06:03:00	1	-8.3000	72.0000
365	2016-03-21 06:04:00	1	9.9000	73.0000
366	2016-03-21 06:05:00	1	24.5000	58.0000
367	2016-03-21 06:06:00	1	2.2000	41.0000
368	2016-03-21 06:07:00	1	28.8000	79.0000
369	2016-03-21 06:08:00	1	-9.6000	51.0000
370	2016-03-21 06:09:00	1	15.9000	62.0000
371	2016-03-21 06:10:00	1	4.9000	67.0000
372	2016-03-21 06:11:00	1	20.2000	58.0000
373	2016-03-21 06:12:00	1	8.1000	63.0000
374	2016-03-21 06:13:00	1	10.0000	46.0000
375	2016-03-21 06:14:00	1	26.2000	63.0000
376	2016-03-21 06:15:00	1	23.7000	63.0000
377	2016-03-21 06:16:00	1	-6.2000	56.0000
378	2016-03-21 06:17:00	1	-3.6000	64.0000
379	2016-03-21 06:18:00	1	1.7000	41.0000
380	2016-03-21 06:19:00	1	-6.4000	59.0000
381	2016-03-21 06:20:00	1	10.1000	52.0000
382	2016-03-21 06:21:00	1	4.6000	75.0000
383	2016-03-21 06:22:00	1	-6.5000	53.0000
384	2016-03-21 06:23:00	1	14.1000	72.0000
385	2016-03-21 06:24:00	1	-8.0000	73.0000
386	2016-03-21 06:25:00	1	15.8000	58.0000
387	2016-03-21 06:26:00	1	-7.3000	78.0000
388	2016-03-21 06:27:00	1	25.1000	50.0000
389	2016-03-21 06:28:00	1	-1.5000	42.0000
390	2016-03-21 06:29:00	1	-7.3000	52.0000
391	2016-03-21 06:30:00	1	-5.1000	60.0000
392	2016-03-21 06:31:00	1	25.1000	53.0000
393	2016-03-21 06:32:00	1	-9.7000	44.0000
394	2016-03-21 06:33:00	1	0.9000	41.0000
395	2016-03-21 06:34:00	1	-0.5000	53.0000
396	2016-03-21 06:35:00	1	-6.4000	59.0000
397	2016-03-21 06:36:00	1	2.6000	78.0000
398	2016-03-21 06:37:00	1	11.9000	58.0000
399	2016-03-21 06:38:00	1	21.5000	49.0000
400	2016-03-21 06:39:00	1	9.9000	75.0000
401	2016-03-21 06:40:00	1	6.0000	45.0000
402	2016-03-21 06:41:00	1	0.3000	42.0000
403	2016-03-21 06:42:00	1	11.7000	49.0000
404	2016-03-21 06:43:00	1	29.5000	43.0000
405	2016-03-21 06:44:00	1	10.5000	48.0000
406	2016-03-21 06:45:00	1	24.9000	75.0000
407	2016-03-21 06:46:00	1	28.7000	51.0000
408	2016-03-21 06:47:00	1	24.1000	44.0000
409	2016-03-21 06:48:00	1	21.5000	44.0000
410	2016-03-21 06:49:00	1	0.9000	40.0000
411	2016-03-21 06:50:00	1	9.4000	45.0000
412	2016-03-21 06:51:00	1	20.6000	43.0000
413	2016-03-21 06:52:00	1	22.6000	53.0000
414	2016-03-21 06:53:00	1	-1.9000	74.0000
415	2016-03-21 06:54:00	1	8.4000	51.0000
416	2016-03-21 06:55:00	1	7.5000	43.0000
417	2016-03-21 06:56:00	1	23.7000	63.0000
418	2016-03-21 06:57:00	1	3.1000	58.0000
419	2016-03-21 06:58:00	1	23.2000	57.0000
420	2016-03-21 06:59:00	1	-4.4000	41.0000
421	2016-03-21 07:00:00	1	4.8000	56.0000
422	2016-03-21 07:01:00	1	29.2000	53.0000
423	2016-03-21 07:02:00	1	20.5000	43.0000
424	2016-03-21 07:03:00	1	2.4000	42.0000
425	2016-03-21 07:04:00	1	28.3000	42.0000
426	2016-03-21 07:05:00	1	13.0000	66.0000
427	2016-03-21 07:06:00	1	27.8000	41.0000
428	2016-03-21 07:07:00	1	-0.3000	71.0000
429	2016-03-21 07:08:00	1	16.0000	50.0000
430	2016-03-21 07:09:00	1	4.4000	56.0000
431	2016-03-21 07:10:00	1	-4.3000	75.0000
432	2016-03-21 07:11:00	1	28.9000	56.0000
433	2016-03-21 07:12:00	1	9.8000	65.0000
434	2016-03-21 07:13:00	1	4.9000	49.0000
435	2016-03-21 07:14:00	1	14.6000	54.0000
436	2016-03-21 07:15:00	1	16.8000	48.0000
437	2016-03-21 07:16:00	1	11.0000	67.0000
438	2016-03-21 07:17:00	1	2.9000	57.0000
439	2016-03-21 07:18:00	1	9.2000	59.0000
440	2016-03-21 07:19:00	1	23.5000	58.0000
441	2016-03-21 07:20:00	1	-1.4000	62.0000
442	2016-03-21 07:21:00	1	25.2000	69.0000
443	2016-03-21 07:22:00	1	20.0000	72.0000
444	2016-03-21 07:23:00	1	26.7000	58.0000
445	2016-03-21 07:24:00	1	12.7000	65.0000
446	2016-03-21 07:25:00	1	10.5000	43.0000
447	2016-03-21 07:26:00	1	-6.9000	54.0000
448	2016-03-21 07:27:00	1	17.9000	58.0000
449	2016-03-21 07:28:00	1	21.4000	52.0000
450	2016-03-21 07:29:00	1	25.8000	42.0000
451	2016-03-21 07:30:00	1	13.3000	58.0000
452	2016-03-21 07:31:00	1	5.4000	56.0000
453	2016-03-21 07:32:00	1	-1.4000	51.0000
454	2016-03-21 07:33:00	1	5.9000	75.0000
455	2016-03-21 07:34:00	1	3.5000	73.0000
456	2016-03-21 07:35:00	1	-4.7000	50.0000
457	2016-03-21 07:36:00	1	15.9000	76.0000
458	2016-03-21 07:37:00	1	18.4000	58.0000
459	2016-03-21 07:38:00	1	-4.5000	79.0000
460	2016-03-21 07:39:00	1	22.0000	51.0000
461	2016-03-21 07:40:00	1	26.3000	49.0000
462	2016-03-21 07:41:00	1	6.7000	64.0000
463	2016-03-21 07:42:00	1	21.9000	52.0000
464	2016-03-21 07:43:00	1	12.3000	42.0000
465	2016-03-21 07:44:00	1	-2.5000	50.0000
466	2016-03-21 07:45:00	1	29.2000	51.0000
467	2016-03-21 07:46:00	1	-9.3000	53.0000
468	2016-03-21 07:47:00	1	25.1000	53.0000
469	2016-03-21 07:48:00	1	-7.2000	41.0000
470	2016-03-21 07:49:00	1	27.1000	54.0000
471	2016-03-21 07:50:00	1	10.4000	60.0000
472	2016-03-21 07:51:00	1	28.4000	69.0000
473	2016-03-21 07:52:00	1	-7.0000	43.0000
474	2016-03-21 07:53:00	1	12.2000	45.0000
475	2016-03-21 07:54:00	1	1.9000	61.0000
476	2016-03-21 07:55:00	1	26.8000	45.0000
477	2016-03-21 07:56:00	1	16.7000	69.0000
478	2016-03-21 07:57:00	1	-2.4000	54.0000
479	2016-03-21 07:58:00	1	8.2000	71.0000
480	2016-03-21 07:59:00	1	-8.1000	47.0000
481	2016-03-21 08:00:00	1	-2.0000	40.0000
482	2016-03-21 08:01:00	1	6.5000	69.0000
483	2016-03-21 08:02:00	1	5.7000	45.0000
484	2016-03-21 08:03:00	1	8.0000	78.0000
485	2016-03-21 08:04:00	1	12.7000	50.0000
486	2016-03-21 08:05:00	1	24.8000	40.0000
487	2016-03-21 08:06:00	1	7.6000	55.0000
488	2016-03-21 08:07:00	1	-0.6000	66.0000
489	2016-03-21 08:08:00	1	9.9000	75.0000
490	2016-03-21 08:09:00	1	19.1000	79.0000
491	2016-03-21 08:10:00	1	-4.3000	67.0000
492	2016-03-21 08:11:00	1	-9.9000	47.0000
493	2016-03-21 08:12:00	1	29.5000	73.0000
494	2016-03-21 08:13:00	1	1.0000	58.0000
495	2016-03-21 08:14:00	1	27.6000	77.0000
496	2016-03-21 08:15:00	1	-6.6000	45.0000
497	2016-03-21 08:16:00	1	3.9000	42.0000
498	2016-03-21 08:17:00	1	4.3000	51.0000
499	2016-03-21 08:18:00	1	21.5000	55.0000
500	2016-03-21 08:19:00	1	-1.9000	53.0000
501	2016-03-21 08:20:00	1	-2.6000	40.0000
502	2016-03-21 08:21:00	1	7.3000	54.0000
503	2016-03-21 08:22:00	1	26.1000	43.0000
504	2016-03-21 08:23:00	1	-4.5000	54.0000
505	2016-03-21 08:24:00	1	8.2000	51.0000
506	2016-03-21 08:25:00	1	-2.1000	54.0000
507	2016-03-21 08:26:00	1	10.5000	57.0000
508	2016-03-21 08:27:00	1	6.4000	54.0000
509	2016-03-21 08:28:00	1	5.7000	43.0000
510	2016-03-21 08:29:00	1	27.6000	73.0000
511	2016-03-21 08:30:00	1	-9.8000	76.0000
512	2016-03-21 08:31:00	1	8.9000	57.0000
513	2016-03-21 08:32:00	1	10.9000	51.0000
514	2016-03-21 08:33:00	1	-6.3000	45.0000
515	2016-03-21 08:34:00	1	15.4000	77.0000
516	2016-03-21 08:35:00	1	16.7000	51.0000
517	2016-03-21 08:36:00	1	4.7000	52.0000
518	2016-03-21 08:37:00	1	7.7000	53.0000
519	2016-03-21 08:38:00	1	20.7000	46.0000
520	2016-03-21 08:39:00	1	16.8000	53.0000
521	2016-03-21 08:40:00	1	7.8000	59.0000
522	2016-03-21 08:41:00	1	22.9000	56.0000
523	2016-03-21 08:42:00	1	-7.4000	49.0000
524	2016-03-21 08:43:00	1	8.3000	66.0000
525	2016-03-21 08:44:00	1	26.6000	42.0000
526	2016-03-21 08:45:00	1	21.6000	52.0000
527	2016-03-21 08:46:00	1	7.0000	77.0000
528	2016-03-21 08:47:00	1	0.9000	76.0000
529	2016-03-21 08:48:00	1	-6.3000	77.0000
530	2016-03-21 08:49:00	1	0.4000	55.0000
531	2016-03-21 08:50:00	1	16.5000	40.0000
532	2016-03-21 08:51:00	1	11.9000	72.0000
533	2016-03-21 08:52:00	1	-8.9000	72.0000
534	2016-03-21 08:53:00	1	2.0000	67.0000
535	2016-03-21 08:54:00	1	12.9000	52.0000
536	2016-03-21 08:55:00	1	-9.3000	56.0000
537	2016-03-21 08:56:00	1	23.4000	47.0000
538	2016-03-21 08:57:00	1	29.1000	48.0000
539	2016-03-21 08:58:00	1	-7.2000	42.0000
540	2016-03-21 08:59:00	1	4.3000	48.0000
541	2016-03-21 09:00:00	1	23.4000	53.0000
542	2016-03-21 09:01:00	1	26.2000	61.0000
543	2016-03-21 09:02:00	1	6.4000	69.0000
544	2016-03-21 09:03:00	1	-1.7000	78.0000
545	2016-03-21 09:04:00	1	11.7000	78.0000
546	2016-03-21 09:05:00	1	-0.8000	61.0000
547	2016-03-21 09:06:00	1	5.7000	59.0000
548	2016-03-21 09:07:00	1	-0.6000	50.0000
549	2016-03-21 09:08:00	1	20.8000	58.0000
550	2016-03-21 09:09:00	1	-1.4000	49.0000
551	2016-03-21 09:10:00	1	10.1000	57.0000
552	2016-03-21 09:11:00	1	4.4000	41.0000
553	2016-03-21 09:12:00	1	-7.2000	77.0000
554	2016-03-21 09:13:00	1	-0.5000	41.0000
555	2016-03-21 09:14:00	1	20.9000	62.0000
556	2016-03-21 09:15:00	1	-5.0000	42.0000
557	2016-03-21 09:16:00	1	19.8000	48.0000
558	2016-03-21 09:17:00	1	24.7000	65.0000
559	2016-03-21 09:18:00	1	-1.7000	40.0000
560	2016-03-21 09:19:00	1	16.3000	43.0000
561	2016-03-21 09:20:00	1	11.6000	56.0000
562	2016-03-21 09:21:00	1	28.3000	76.0000
563	2016-03-21 09:22:00	1	16.5000	77.0000
564	2016-03-21 09:23:00	1	4.1000	66.0000
565	2016-03-21 09:24:00	1	19.0000	62.0000
566	2016-03-21 09:25:00	1	21.0000	65.0000
567	2016-03-21 09:26:00	1	21.9000	61.0000
568	2016-03-21 09:27:00	1	12.6000	63.0000
569	2016-03-21 09:28:00	1	8.9000	75.0000
570	2016-03-21 09:29:00	1	-9.6000	77.0000
571	2016-03-21 09:30:00	1	6.0000	53.0000
572	2016-03-21 09:31:00	1	24.2000	73.0000
573	2016-03-21 09:32:00	1	-3.4000	63.0000
574	2016-03-21 09:33:00	1	2.0000	57.0000
575	2016-03-21 09:34:00	1	21.8000	40.0000
576	2016-03-21 09:35:00	1	-5.0000	61.0000
577	2016-03-21 09:36:00	1	23.8000	44.0000
578	2016-03-21 09:37:00	1	0.7000	70.0000
579	2016-03-21 09:38:00	1	0.9000	62.0000
580	2016-03-21 09:39:00	1	27.6000	76.0000
581	2016-03-21 09:40:00	1	-2.4000	51.0000
582	2016-03-21 09:41:00	1	-1.1000	64.0000
583	2016-03-21 09:42:00	1	24.0000	67.0000
584	2016-03-21 09:43:00	1	24.3000	49.0000
585	2016-03-21 09:44:00	1	13.6000	51.0000
586	2016-03-21 09:45:00	1	12.7000	40.0000
587	2016-03-21 09:46:00	1	-10.0000	66.0000
588	2016-03-21 09:47:00	1	-4.6000	45.0000
589	2016-03-21 09:48:00	1	-4.3000	50.0000
590	2016-03-21 09:49:00	1	11.6000	72.0000
591	2016-03-21 09:50:00	1	5.7000	43.0000
592	2016-03-21 09:51:00	1	0.9000	65.0000
593	2016-03-21 09:52:00	1	19.9000	50.0000
594	2016-03-21 09:53:00	1	19.8000	68.0000
595	2016-03-21 09:54:00	1	-3.5000	51.0000
596	2016-03-21 09:55:00	1	-9.3000	57.0000
597	2016-03-21 09:56:00	1	6.0000	65.0000
598	2016-03-21 09:57:00	1	3.5000	53.0000
599	2016-03-21 09:58:00	1	-8.9000	49.0000
600	2016-03-21 09:59:00	1	12.8000	74.0000
601	2016-03-21 10:00:00	1	-7.6000	69.0000
602	2016-03-21 10:01:00	1	14.3000	44.0000
603	2016-03-21 10:02:00	1	12.3000	67.0000
604	2016-03-21 10:03:00	1	-1.0000	63.0000
605	2016-03-21 10:04:00	1	-2.8000	51.0000
606	2016-03-21 10:05:00	1	15.4000	66.0000
607	2016-03-21 10:06:00	1	7.2000	48.0000
608	2016-03-21 10:07:00	1	22.4000	41.0000
609	2016-03-21 10:08:00	1	7.9000	46.0000
610	2016-03-21 10:09:00	1	-2.0000	50.0000
611	2016-03-21 10:10:00	1	-0.4000	53.0000
612	2016-03-21 10:11:00	1	28.4000	59.0000
613	2016-03-21 10:12:00	1	8.4000	69.0000
614	2016-03-21 10:13:00	1	25.5000	50.0000
615	2016-03-21 10:14:00	1	9.7000	74.0000
616	2016-03-21 10:15:00	1	-5.8000	78.0000
617	2016-03-21 10:16:00	1	13.7000	79.0000
618	2016-03-21 10:17:00	1	14.5000	77.0000
619	2016-03-21 10:18:00	1	8.3000	71.0000
620	2016-03-21 10:19:00	1	24.0000	43.0000
621	2016-03-21 10:20:00	1	14.1000	54.0000
622	2016-03-21 10:21:00	1	-1.6000	76.0000
623	2016-03-21 10:22:00	1	5.7000	40.0000
624	2016-03-21 10:23:00	1	-1.5000	79.0000
625	2016-03-21 10:24:00	1	13.0000	46.0000
626	2016-03-21 10:25:00	1	7.9000	43.0000
627	2016-03-21 10:26:00	1	15.3000	58.0000
628	2016-03-21 10:27:00	1	8.2000	76.0000
629	2016-03-21 10:28:00	1	18.2000	53.0000
630	2016-03-21 10:29:00	1	13.1000	65.0000
631	2016-03-21 10:30:00	1	21.9000	51.0000
632	2016-03-21 10:31:00	1	19.9000	50.0000
633	2016-03-21 10:32:00	1	5.9000	45.0000
634	2016-03-21 10:33:00	1	11.6000	55.0000
635	2016-03-21 10:34:00	1	-2.2000	66.0000
636	2016-03-21 10:35:00	1	9.7000	59.0000
637	2016-03-21 10:36:00	1	24.9000	47.0000
638	2016-03-21 10:37:00	1	23.3000	61.0000
639	2016-03-21 10:38:00	1	18.9000	52.0000
640	2016-03-21 10:39:00	1	-5.8000	53.0000
641	2016-03-21 10:40:00	1	8.3000	50.0000
642	2016-03-21 10:41:00	1	-5.4000	56.0000
643	2016-03-21 10:42:00	1	28.4000	78.0000
644	2016-03-21 10:43:00	1	-2.8000	55.0000
645	2016-03-21 10:44:00	1	26.4000	59.0000
646	2016-03-21 10:45:00	1	24.4000	79.0000
647	2016-03-21 10:46:00	1	7.6000	42.0000
648	2016-03-21 10:47:00	1	-6.1000	59.0000
649	2016-03-21 10:48:00	1	28.6000	55.0000
650	2016-03-21 10:49:00	1	17.6000	45.0000
651	2016-03-21 10:50:00	1	-9.0000	53.0000
652	2016-03-21 10:51:00	1	28.4000	40.0000
653	2016-03-21 10:52:00	1	25.4000	59.0000
654	2016-03-21 10:53:00	1	-3.4000	66.0000
655	2016-03-21 10:54:00	1	23.4000	41.0000
656	2016-03-21 10:55:00	1	26.2000	49.0000
657	2016-03-21 10:56:00	1	23.0000	56.0000
658	2016-03-21 10:57:00	1	5.3000	59.0000
659	2016-03-21 10:58:00	1	13.5000	78.0000
660	2016-03-21 10:59:00	1	7.9000	46.0000
661	2016-03-21 11:00:00	1	2.8000	73.0000
662	2016-03-21 11:01:00	1	-1.7000	47.0000
663	2016-03-21 11:02:00	1	26.6000	53.0000
664	2016-03-21 11:03:00	1	13.9000	44.0000
665	2016-03-21 11:04:00	1	27.7000	41.0000
666	2016-03-21 11:05:00	1	-8.3000	48.0000
667	2016-03-21 11:06:00	1	8.9000	52.0000
668	2016-03-21 11:07:00	1	24.7000	53.0000
669	2016-03-21 11:08:00	1	21.7000	48.0000
670	2016-03-21 11:09:00	1	28.5000	43.0000
671	2016-03-21 11:10:00	1	2.2000	59.0000
672	2016-03-21 11:11:00	1	26.9000	41.0000
673	2016-03-21 11:12:00	1	25.5000	77.0000
674	2016-03-21 11:13:00	1	26.6000	70.0000
675	2016-03-21 11:14:00	1	24.8000	53.0000
676	2016-03-21 11:15:00	1	29.0000	53.0000
677	2016-03-21 11:16:00	1	16.9000	41.0000
678	2016-03-21 11:17:00	1	28.1000	42.0000
679	2016-03-21 11:18:00	1	9.4000	46.0000
680	2016-03-21 11:19:00	1	8.7000	62.0000
681	2016-03-21 11:20:00	1	23.6000	54.0000
682	2016-03-21 11:21:00	1	5.9000	41.0000
683	2016-03-21 11:22:00	1	10.5000	77.0000
684	2016-03-21 11:23:00	1	16.7000	57.0000
685	2016-03-21 11:24:00	1	1.9000	75.0000
686	2016-03-21 11:25:00	1	27.4000	74.0000
687	2016-03-21 11:26:00	1	9.9000	51.0000
688	2016-03-21 11:27:00	1	19.4000	50.0000
689	2016-03-21 11:28:00	1	-3.4000	75.0000
690	2016-03-21 11:29:00	1	24.4000	64.0000
691	2016-03-21 11:30:00	1	-9.5000	75.0000
692	2016-03-21 11:31:00	1	-0.9000	75.0000
693	2016-03-21 11:32:00	1	-9.4000	57.0000
694	2016-03-21 11:33:00	1	0.9000	50.0000
695	2016-03-21 11:34:00	1	19.2000	43.0000
696	2016-03-21 11:35:00	1	27.1000	70.0000
697	2016-03-21 11:36:00	1	0.0000	61.0000
698	2016-03-21 11:37:00	1	25.1000	43.0000
699	2016-03-21 11:38:00	1	13.6000	66.0000
700	2016-03-21 11:39:00	1	-7.3000	64.0000
701	2016-03-21 11:40:00	1	-3.1000	60.0000
702	2016-03-21 11:41:00	1	9.7000	55.0000
703	2016-03-21 11:42:00	1	24.4000	53.0000
704	2016-03-21 11:43:00	1	-7.8000	60.0000
705	2016-03-21 11:44:00	1	25.1000	64.0000
706	2016-03-21 11:45:00	1	-7.6000	56.0000
707	2016-03-21 11:46:00	1	19.9000	61.0000
708	2016-03-21 11:47:00	1	13.0000	75.0000
709	2016-03-21 11:48:00	1	8.6000	47.0000
710	2016-03-21 11:49:00	1	0.5000	61.0000
711	2016-03-21 11:50:00	1	13.4000	57.0000
712	2016-03-21 11:51:00	1	20.5000	67.0000
713	2016-03-21 11:52:00	1	10.7000	63.0000
714	2016-03-21 11:53:00	1	13.8000	56.0000
715	2016-03-21 11:54:00	1	-2.6000	51.0000
716	2016-03-21 11:55:00	1	29.8000	49.0000
717	2016-03-21 11:56:00	1	16.6000	58.0000
718	2016-03-21 11:57:00	1	-8.8000	62.0000
719	2016-03-21 11:58:00	1	18.6000	48.0000
720	2016-03-21 11:59:00	1	12.0000	78.0000
721	2016-03-21 12:00:00	1	29.9000	46.0000
722	2016-03-21 12:01:00	1	9.2000	51.0000
723	2016-03-21 12:02:00	1	25.9000	44.0000
724	2016-03-21 12:03:00	1	10.3000	65.0000
725	2016-03-21 12:04:00	1	26.1000	51.0000
726	2016-03-21 12:05:00	1	12.3000	62.0000
727	2016-03-21 12:06:00	1	28.5000	57.0000
728	2016-03-21 12:07:00	1	2.9000	46.0000
729	2016-03-21 12:08:00	1	28.5000	60.0000
730	2016-03-21 12:09:00	1	13.4000	69.0000
731	2016-03-21 12:10:00	1	13.2000	42.0000
732	2016-03-21 12:11:00	1	10.2000	41.0000
733	2016-03-21 12:12:00	1	-7.4000	62.0000
734	2016-03-21 12:13:00	1	20.8000	51.0000
735	2016-03-21 12:14:00	1	14.8000	45.0000
736	2016-03-21 12:15:00	1	4.8000	42.0000
737	2016-03-21 12:16:00	1	27.3000	43.0000
738	2016-03-21 12:17:00	1	4.4000	79.0000
739	2016-03-21 12:18:00	1	26.3000	79.0000
740	2016-03-21 12:19:00	1	-2.2000	59.0000
741	2016-03-21 12:20:00	1	15.5000	71.0000
742	2016-03-21 12:21:00	1	1.9000	58.0000
743	2016-03-21 12:22:00	1	-7.1000	50.0000
744	2016-03-21 12:23:00	1	-7.0000	68.0000
745	2016-03-21 12:24:00	1	11.5000	47.0000
746	2016-03-21 12:25:00	1	-2.7000	60.0000
747	2016-03-21 12:26:00	1	-0.4000	55.0000
748	2016-03-21 12:27:00	1	4.5000	69.0000
749	2016-03-21 12:28:00	1	-1.1000	65.0000
750	2016-03-21 12:29:00	1	-6.6000	67.0000
751	2016-03-21 12:30:00	1	8.2000	50.0000
752	2016-03-21 12:31:00	1	8.4000	62.0000
753	2016-03-21 12:32:00	1	2.3000	43.0000
754	2016-03-21 12:33:00	1	-1.4000	61.0000
755	2016-03-21 12:34:00	1	17.5000	66.0000
756	2016-03-21 12:35:00	1	-9.0000	53.0000
757	2016-03-21 12:36:00	1	-3.5000	61.0000
758	2016-03-21 12:37:00	1	26.9000	45.0000
759	2016-03-21 12:38:00	1	27.8000	56.0000
760	2016-03-21 12:39:00	1	0.8000	62.0000
761	2016-03-21 12:40:00	1	16.3000	70.0000
762	2016-03-21 12:41:00	1	14.0000	52.0000
763	2016-03-21 12:42:00	1	-4.4000	44.0000
764	2016-03-21 12:43:00	1	-1.9000	61.0000
765	2016-03-21 12:44:00	1	-6.1000	41.0000
766	2016-03-21 12:45:00	1	-1.8000	58.0000
767	2016-03-21 12:46:00	1	19.7000	59.0000
768	2016-03-21 12:47:00	1	27.5000	44.0000
769	2016-03-21 12:48:00	1	9.4000	41.0000
770	2016-03-21 12:49:00	1	0.6000	65.0000
771	2016-03-21 12:50:00	1	12.5000	65.0000
772	2016-03-21 12:51:00	1	9.8000	43.0000
773	2016-03-21 12:52:00	1	14.5000	50.0000
774	2016-03-21 12:53:00	1	28.5000	58.0000
775	2016-03-21 12:54:00	1	6.6000	61.0000
776	2016-03-21 12:55:00	1	-8.4000	68.0000
777	2016-03-21 12:56:00	1	17.4000	43.0000
778	2016-03-21 12:57:00	1	28.8000	55.0000
779	2016-03-21 12:58:00	1	14.2000	41.0000
780	2016-03-21 12:59:00	1	-2.5000	55.0000
781	2016-03-21 13:00:00	1	8.4000	66.0000
782	2016-03-21 13:01:00	1	0.1000	53.0000
783	2016-03-21 13:02:00	1	-7.7000	73.0000
784	2016-03-21 13:03:00	1	0.0000	46.0000
785	2016-03-21 13:04:00	1	3.7000	62.0000
786	2016-03-21 13:05:00	1	18.5000	60.0000
787	2016-03-21 13:06:00	1	22.2000	69.0000
788	2016-03-21 13:07:00	1	15.3000	54.0000
789	2016-03-21 13:08:00	1	14.9000	50.0000
790	2016-03-21 13:09:00	1	29.0000	44.0000
791	2016-03-21 13:10:00	1	23.1000	72.0000
792	2016-03-21 13:11:00	1	-5.6000	42.0000
793	2016-03-21 13:12:00	1	16.2000	52.0000
794	2016-03-21 13:13:00	1	3.5000	61.0000
795	2016-03-21 13:14:00	1	0.2000	74.0000
796	2016-03-21 13:15:00	1	28.4000	75.0000
797	2016-03-21 13:16:00	1	26.7000	49.0000
798	2016-03-21 13:17:00	1	26.6000	64.0000
799	2016-03-21 13:18:00	1	6.1000	45.0000
800	2016-03-21 13:19:00	1	10.7000	55.0000
801	2016-03-21 13:20:00	1	17.2000	61.0000
802	2016-03-21 13:21:00	1	16.0000	74.0000
803	2016-03-21 13:22:00	1	7.4000	57.0000
804	2016-03-21 13:23:00	1	26.1000	48.0000
805	2016-03-21 13:24:00	1	25.1000	60.0000
806	2016-03-21 13:25:00	1	-6.1000	59.0000
807	2016-03-21 13:26:00	1	25.7000	45.0000
808	2016-03-21 13:27:00	1	-1.3000	66.0000
809	2016-03-21 13:28:00	1	1.5000	78.0000
810	2016-03-21 13:29:00	1	22.2000	70.0000
811	2016-03-21 13:30:00	1	-6.8000	63.0000
812	2016-03-21 13:31:00	1	0.3000	52.0000
813	2016-03-21 13:32:00	1	29.1000	73.0000
814	2016-03-21 13:33:00	1	28.9000	54.0000
815	2016-03-21 13:34:00	1	3.5000	66.0000
816	2016-03-21 13:35:00	1	-5.1000	64.0000
817	2016-03-21 13:36:00	1	18.7000	43.0000
818	2016-03-21 13:37:00	1	10.2000	57.0000
819	2016-03-21 13:38:00	1	-7.8000	46.0000
820	2016-03-21 13:39:00	1	-1.5000	48.0000
821	2016-03-21 13:40:00	1	1.5000	77.0000
822	2016-03-21 13:41:00	1	15.5000	57.0000
823	2016-03-21 13:42:00	1	10.7000	47.0000
824	2016-03-21 13:43:00	1	19.1000	79.0000
825	2016-03-21 13:44:00	1	6.5000	70.0000
826	2016-03-21 13:45:00	1	3.9000	58.0000
827	2016-03-21 13:46:00	1	2.0000	54.0000
828	2016-03-21 13:47:00	1	9.5000	65.0000
829	2016-03-21 13:48:00	1	21.1000	66.0000
830	2016-03-21 13:49:00	1	16.3000	44.0000
831	2016-03-21 13:50:00	1	28.0000	67.0000
832	2016-03-21 13:51:00	1	-4.6000	79.0000
833	2016-03-21 13:52:00	1	12.2000	47.0000
834	2016-03-21 13:53:00	1	22.8000	70.0000
835	2016-03-21 13:54:00	1	-8.1000	60.0000
836	2016-03-21 13:55:00	1	11.7000	57.0000
837	2016-03-21 13:56:00	1	3.6000	45.0000
838	2016-03-21 13:57:00	1	10.6000	79.0000
839	2016-03-21 13:58:00	1	-8.5000	57.0000
840	2016-03-21 13:59:00	1	16.5000	58.0000
841	2016-03-21 14:00:00	1	21.0000	48.0000
842	2016-03-21 14:01:00	1	27.6000	40.0000
843	2016-03-21 14:02:00	1	14.6000	66.0000
844	2016-03-21 14:03:00	1	4.0000	50.0000
845	2016-03-21 14:04:00	1	25.6000	64.0000
846	2016-03-21 14:05:00	1	10.2000	43.0000
847	2016-03-21 14:06:00	1	21.5000	43.0000
848	2016-03-21 14:07:00	1	10.2000	41.0000
849	2016-03-21 14:08:00	1	1.2000	57.0000
850	2016-03-21 14:09:00	1	28.1000	61.0000
851	2016-03-21 14:10:00	1	4.3000	70.0000
852	2016-03-21 14:11:00	1	16.5000	55.0000
853	2016-03-21 14:12:00	1	17.1000	53.0000
854	2016-03-21 14:13:00	1	12.2000	47.0000
855	2016-03-21 14:14:00	1	6.7000	73.0000
856	2016-03-21 14:15:00	1	-3.4000	57.0000
857	2016-03-21 14:16:00	1	-0.9000	60.0000
858	2016-03-21 14:17:00	1	0.6000	63.0000
859	2016-03-21 14:18:00	1	11.4000	42.0000
860	2016-03-21 14:19:00	1	-0.6000	78.0000
861	2016-03-21 14:20:00	1	14.9000	47.0000
862	2016-03-21 14:21:00	1	0.5000	78.0000
863	2016-03-21 14:22:00	1	5.2000	43.0000
864	2016-03-21 14:23:00	1	20.2000	59.0000
865	2016-03-21 14:24:00	1	-6.2000	71.0000
866	2016-03-21 14:25:00	1	29.5000	78.0000
867	2016-03-21 14:26:00	1	-1.9000	79.0000
868	2016-03-21 14:27:00	1	-4.0000	56.0000
869	2016-03-21 14:28:00	1	23.1000	47.0000
870	2016-03-21 14:29:00	1	13.7000	41.0000
871	2016-03-21 14:30:00	1	26.9000	47.0000
872	2016-03-21 14:31:00	1	7.4000	61.0000
873	2016-03-21 14:32:00	1	24.5000	55.0000
874	2016-03-21 14:33:00	1	29.8000	54.0000
875	2016-03-21 14:34:00	1	2.6000	57.0000
876	2016-03-21 14:35:00	1	22.8000	44.0000
877	2016-03-21 14:36:00	1	28.7000	72.0000
878	2016-03-21 14:37:00	1	4.0000	73.0000
879	2016-03-21 14:38:00	1	24.1000	60.0000
880	2016-03-21 14:39:00	1	-9.6000	76.0000
881	2016-03-21 14:40:00	1	22.4000	72.0000
882	2016-03-21 14:41:00	1	6.0000	72.0000
883	2016-03-21 14:42:00	1	15.9000	66.0000
884	2016-03-21 14:43:00	1	25.6000	62.0000
885	2016-03-21 14:44:00	1	0.2000	50.0000
886	2016-03-21 14:45:00	1	18.7000	53.0000
887	2016-03-21 14:46:00	1	-0.4000	41.0000
888	2016-03-21 14:47:00	1	3.2000	44.0000
889	2016-03-21 14:48:00	1	24.1000	57.0000
890	2016-03-21 14:49:00	1	9.9000	73.0000
891	2016-03-21 14:50:00	1	12.1000	69.0000
892	2016-03-21 14:51:00	1	-5.9000	58.0000
893	2016-03-21 14:52:00	1	6.1000	58.0000
894	2016-03-21 14:53:00	1	24.8000	57.0000
895	2016-03-21 14:54:00	1	12.2000	44.0000
896	2016-03-21 14:55:00	1	-1.8000	69.0000
897	2016-03-21 14:56:00	1	25.1000	46.0000
898	2016-03-21 14:57:00	1	5.1000	46.0000
899	2016-03-21 14:58:00	1	-3.8000	49.0000
900	2016-03-21 14:59:00	1	-10.0000	66.0000
901	2016-03-21 15:00:00	1	19.9000	71.0000
902	2016-03-21 15:01:00	1	13.6000	56.0000
903	2016-03-21 15:02:00	1	24.8000	72.0000
904	2016-03-21 15:03:00	1	-6.4000	67.0000
905	2016-03-21 15:04:00	1	-0.2000	58.0000
906	2016-03-21 15:05:00	1	25.5000	43.0000
907	2016-03-21 15:06:00	1	26.2000	76.0000
908	2016-03-21 15:07:00	1	2.8000	49.0000
909	2016-03-21 15:08:00	1	7.7000	53.0000
910	2016-03-21 15:09:00	1	12.5000	72.0000
911	2016-03-21 15:10:00	1	-7.2000	79.0000
912	2016-03-21 15:11:00	1	4.6000	72.0000
913	2016-03-21 15:12:00	1	4.8000	43.0000
914	2016-03-21 15:13:00	1	9.0000	58.0000
915	2016-03-21 15:14:00	1	-9.7000	66.0000
916	2016-03-21 15:15:00	1	27.4000	51.0000
917	2016-03-21 15:16:00	1	-2.3000	42.0000
918	2016-03-21 15:17:00	1	19.8000	68.0000
919	2016-03-21 15:18:00	1	7.8000	47.0000
920	2016-03-21 15:19:00	1	21.4000	43.0000
921	2016-03-21 15:20:00	1	6.8000	55.0000
922	2016-03-21 15:21:00	1	9.4000	53.0000
923	2016-03-21 15:22:00	1	16.5000	47.0000
924	2016-03-21 15:23:00	1	15.2000	44.0000
925	2016-03-21 15:24:00	1	29.7000	69.0000
926	2016-03-21 15:25:00	1	-5.8000	56.0000
927	2016-03-21 15:26:00	1	28.3000	58.0000
928	2016-03-21 15:27:00	1	-9.5000	53.0000
929	2016-03-21 15:28:00	1	-1.6000	66.0000
930	2016-03-21 15:29:00	1	24.2000	73.0000
931	2016-03-21 15:30:00	1	28.4000	55.0000
932	2016-03-21 15:31:00	1	29.0000	69.0000
933	2016-03-21 15:32:00	1	2.6000	71.0000
934	2016-03-21 15:33:00	1	-1.4000	51.0000
935	2016-03-21 15:34:00	1	12.1000	52.0000
936	2016-03-21 15:35:00	1	7.9000	44.0000
937	2016-03-21 15:36:00	1	16.8000	40.0000
938	2016-03-21 15:37:00	1	1.8000	77.0000
939	2016-03-21 15:38:00	1	19.5000	60.0000
940	2016-03-21 15:39:00	1	7.5000	47.0000
941	2016-03-21 15:40:00	1	-5.3000	78.0000
942	2016-03-21 15:41:00	1	21.8000	76.0000
943	2016-03-21 15:42:00	1	-9.5000	71.0000
944	2016-03-21 15:43:00	1	6.2000	57.0000
945	2016-03-21 15:44:00	1	1.6000	61.0000
946	2016-03-21 15:45:00	1	7.7000	69.0000
947	2016-03-21 15:46:00	1	-8.0000	74.0000
948	2016-03-21 15:47:00	1	6.1000	73.0000
949	2016-03-21 15:48:00	1	-4.5000	54.0000
950	2016-03-21 15:49:00	1	-5.0000	43.0000
951	2016-03-21 15:50:00	1	14.6000	58.0000
952	2016-03-21 15:51:00	1	16.5000	53.0000
953	2016-03-21 15:52:00	1	10.2000	44.0000
954	2016-03-21 15:53:00	1	14.7000	45.0000
955	2016-03-21 15:54:00	1	25.2000	52.0000
956	2016-03-21 15:55:00	1	28.9000	72.0000
957	2016-03-21 15:56:00	1	13.9000	55.0000
958	2016-03-21 15:57:00	1	-7.1000	66.0000
959	2016-03-21 15:58:00	1	12.9000	58.0000
960	2016-03-21 15:59:00	1	23.4000	43.0000
961	2016-03-21 16:00:00	1	19.5000	53.0000
962	2016-03-21 16:01:00	1	-5.5000	55.0000
963	2016-03-21 16:02:00	1	17.8000	70.0000
964	2016-03-21 16:03:00	1	-3.8000	71.0000
965	2016-03-21 16:04:00	1	-4.8000	53.0000
966	2016-03-21 16:05:00	1	10.9000	51.0000
967	2016-03-21 16:06:00	1	24.2000	61.0000
968	2016-03-21 16:07:00	1	-8.9000	69.0000
969	2016-03-21 16:08:00	1	-4.4000	55.0000
970	2016-03-21 16:09:00	1	14.1000	68.0000
971	2016-03-21 16:10:00	1	18.0000	66.0000
972	2016-03-21 16:11:00	1	-9.3000	77.0000
973	2016-03-21 16:12:00	1	3.7000	68.0000
974	2016-03-21 16:13:00	1	26.3000	48.0000
975	2016-03-21 16:14:00	1	12.7000	67.0000
976	2016-03-21 16:15:00	1	21.1000	45.0000
977	2016-03-21 16:16:00	1	-9.2000	64.0000
978	2016-03-21 16:17:00	1	-6.2000	47.0000
979	2016-03-21 16:18:00	1	6.1000	49.0000
980	2016-03-21 16:19:00	1	11.9000	58.0000
981	2016-03-21 16:20:00	1	11.2000	52.0000
982	2016-03-21 16:21:00	1	1.1000	54.0000
983	2016-03-21 16:22:00	1	0.1000	73.0000
984	2016-03-21 16:23:00	1	19.8000	78.0000
985	2016-03-21 16:24:00	1	28.0000	57.0000
986	2016-03-21 16:25:00	1	6.5000	75.0000
987	2016-03-21 16:26:00	1	26.8000	46.0000
988	2016-03-21 16:27:00	1	27.9000	45.0000
989	2016-03-21 16:28:00	1	10.9000	55.0000
990	2016-03-21 16:29:00	1	-3.0000	40.0000
991	2016-03-21 16:30:00	1	13.9000	44.0000
992	2016-03-21 16:31:00	1	5.9000	62.0000
993	2016-03-21 16:32:00	1	23.7000	46.0000
994	2016-03-21 16:33:00	1	3.3000	41.0000
995	2016-03-21 16:34:00	1	19.7000	48.0000
996	2016-03-21 16:35:00	1	21.1000	57.0000
997	2016-03-21 16:36:00	1	27.9000	48.0000
998	2016-03-21 16:37:00	1	16.3000	73.0000
999	2016-03-21 16:38:00	1	4.4000	54.0000
1000	2016-03-21 16:39:00	1	13.8000	49.0000
1001	2016-03-21 16:40:00	1	19.9000	76.0000
1002	2016-03-21 16:41:00	1	28.4000	75.0000
1003	2016-03-21 16:42:00	1	7.6000	56.0000
1004	2016-03-21 16:43:00	1	27.2000	56.0000
1005	2016-03-21 16:44:00	1	20.5000	72.0000
1006	2016-03-21 16:45:00	1	-7.9000	53.0000
1007	2016-03-21 16:46:00	1	-7.6000	42.0000
1008	2016-03-21 16:47:00	1	29.1000	64.0000
1009	2016-03-21 16:48:00	1	27.6000	65.0000
1010	2016-03-21 16:49:00	1	-4.2000	43.0000
1011	2016-03-21 16:50:00	1	-2.4000	44.0000
1012	2016-03-21 16:51:00	1	28.2000	73.0000
1013	2016-03-21 16:52:00	1	29.1000	50.0000
1014	2016-03-21 16:53:00	1	3.6000	53.0000
1015	2016-03-21 16:54:00	1	-9.4000	76.0000
1016	2016-03-21 16:55:00	1	15.8000	75.0000
1017	2016-03-21 16:56:00	1	27.8000	46.0000
1018	2016-03-21 16:57:00	1	7.2000	54.0000
1019	2016-03-21 16:58:00	1	10.4000	49.0000
1020	2016-03-21 16:59:00	1	3.9000	73.0000
1021	2016-03-21 17:00:00	1	8.8000	46.0000
1022	2016-03-21 17:01:00	1	15.4000	58.0000
1023	2016-03-21 17:02:00	1	24.0000	62.0000
1024	2016-03-21 17:03:00	1	7.2000	55.0000
1025	2016-03-21 17:04:00	1	27.0000	66.0000
1026	2016-03-21 17:05:00	1	8.9000	60.0000
1027	2016-03-21 17:06:00	1	9.9000	58.0000
1028	2016-03-21 17:07:00	1	0.1000	62.0000
1029	2016-03-21 17:08:00	1	-8.3000	58.0000
1030	2016-03-21 17:09:00	1	22.4000	72.0000
1031	2016-03-21 17:10:00	1	11.1000	58.0000
1032	2016-03-21 17:11:00	1	22.7000	46.0000
1033	2016-03-21 17:12:00	1	-7.7000	77.0000
1034	2016-03-21 17:13:00	1	24.2000	66.0000
1035	2016-03-21 17:14:00	1	14.4000	49.0000
1036	2016-03-21 17:15:00	1	23.7000	48.0000
1037	2016-03-21 17:16:00	1	14.2000	66.0000
1038	2016-03-21 17:17:00	1	14.4000	62.0000
1039	2016-03-21 17:18:00	1	-6.3000	68.0000
1040	2016-03-21 17:19:00	1	-0.2000	76.0000
1041	2016-03-21 17:20:00	1	14.6000	75.0000
1042	2016-03-21 17:21:00	1	-4.8000	44.0000
1043	2016-03-21 17:22:00	1	-4.1000	50.0000
1044	2016-03-21 17:23:00	1	13.5000	41.0000
1045	2016-03-21 17:24:00	1	28.9000	62.0000
1046	2016-03-21 17:25:00	1	-0.2000	42.0000
1047	2016-03-21 17:26:00	1	24.1000	40.0000
1048	2016-03-21 17:27:00	1	28.9000	44.0000
1049	2016-03-21 17:28:00	1	2.5000	47.0000
1050	2016-03-21 17:29:00	1	9.2000	64.0000
1051	2016-03-21 17:30:00	1	-8.8000	49.0000
1052	2016-03-21 17:31:00	1	-9.9000	51.0000
1053	2016-03-21 17:32:00	1	22.1000	58.0000
1054	2016-03-21 17:33:00	1	-6.4000	44.0000
1055	2016-03-21 17:34:00	1	16.1000	69.0000
1056	2016-03-21 17:35:00	1	26.5000	61.0000
1057	2016-03-21 17:36:00	1	-7.9000	56.0000
1058	2016-03-21 17:37:00	1	5.2000	57.0000
1059	2016-03-21 17:38:00	1	6.9000	52.0000
1060	2016-03-21 17:39:00	1	5.5000	54.0000
1061	2016-03-21 17:40:00	1	4.6000	51.0000
1062	2016-03-21 17:41:00	1	25.9000	53.0000
1063	2016-03-21 17:42:00	1	17.8000	43.0000
1064	2016-03-21 17:43:00	1	-4.9000	68.0000
1065	2016-03-21 17:44:00	1	17.8000	46.0000
1066	2016-03-21 17:45:00	1	27.1000	47.0000
1067	2016-03-21 17:46:00	1	27.3000	64.0000
1068	2016-03-21 17:47:00	1	4.5000	71.0000
1069	2016-03-21 17:48:00	1	11.7000	50.0000
1070	2016-03-21 17:49:00	1	15.2000	49.0000
1071	2016-03-21 17:50:00	1	21.4000	74.0000
1072	2016-03-21 17:51:00	1	8.5000	63.0000
1073	2016-03-21 17:52:00	1	13.3000	55.0000
1074	2016-03-21 17:53:00	1	-8.6000	56.0000
1075	2016-03-21 17:54:00	1	22.4000	58.0000
1076	2016-03-21 17:55:00	1	6.1000	41.0000
1077	2016-03-21 17:56:00	1	-7.8000	45.0000
1078	2016-03-21 17:57:00	1	5.8000	59.0000
1079	2016-03-21 17:58:00	1	-3.3000	50.0000
1080	2016-03-21 17:59:00	1	20.2000	79.0000
1081	2016-03-21 18:00:00	1	-4.8000	59.0000
1082	2016-03-21 18:01:00	1	13.6000	52.0000
1083	2016-03-21 18:02:00	1	14.5000	64.0000
1084	2016-03-21 18:03:00	1	21.9000	45.0000
1085	2016-03-21 18:04:00	1	6.1000	78.0000
1086	2016-03-21 18:05:00	1	4.0000	73.0000
1087	2016-03-21 18:06:00	1	28.7000	43.0000
1088	2016-03-21 18:07:00	1	-9.1000	62.0000
1089	2016-03-21 18:08:00	1	16.2000	76.0000
1090	2016-03-21 18:09:00	1	12.2000	46.0000
1091	2016-03-21 18:10:00	1	9.3000	48.0000
1092	2016-03-21 18:11:00	1	15.6000	42.0000
1093	2016-03-21 18:12:00	1	0.3000	40.0000
1094	2016-03-21 18:13:00	1	1.5000	42.0000
1095	2016-03-21 18:14:00	1	12.3000	68.0000
1096	2016-03-21 18:15:00	1	1.4000	47.0000
1097	2016-03-21 18:16:00	1	19.0000	48.0000
1098	2016-03-21 18:17:00	1	20.0000	69.0000
1099	2016-03-21 18:18:00	1	23.1000	42.0000
1100	2016-03-21 18:19:00	1	9.7000	45.0000
1101	2016-03-21 18:20:00	1	28.9000	47.0000
1102	2016-03-21 18:21:00	1	6.7000	52.0000
1103	2016-03-21 18:22:00	1	16.3000	74.0000
1104	2016-03-21 18:23:00	1	9.5000	49.0000
1105	2016-03-21 18:24:00	1	10.0000	52.0000
1106	2016-03-21 18:25:00	1	21.0000	44.0000
1107	2016-03-21 18:26:00	1	-9.9000	42.0000
1108	2016-03-21 18:27:00	1	10.8000	53.0000
1109	2016-03-21 18:28:00	1	8.0000	47.0000
1110	2016-03-21 18:29:00	1	17.3000	52.0000
1111	2016-03-21 18:30:00	1	23.9000	56.0000
1112	2016-03-21 18:31:00	1	17.8000	42.0000
1113	2016-03-21 18:32:00	1	23.8000	58.0000
1114	2016-03-21 18:33:00	1	26.4000	55.0000
1115	2016-03-21 18:34:00	1	29.5000	46.0000
1116	2016-03-21 18:35:00	1	26.1000	60.0000
1117	2016-03-21 18:36:00	1	-0.2000	57.0000
1118	2016-03-21 18:37:00	1	25.9000	64.0000
1119	2016-03-21 18:38:00	1	20.4000	46.0000
1120	2016-03-21 18:39:00	1	-1.4000	61.0000
1121	2016-03-21 18:40:00	1	7.2000	48.0000
1122	2016-03-21 18:41:00	1	-0.3000	58.0000
1123	2016-03-21 18:42:00	1	6.2000	51.0000
1124	2016-03-21 18:43:00	1	17.7000	51.0000
1125	2016-03-21 18:44:00	1	12.8000	45.0000
1126	2016-03-21 18:45:00	1	24.5000	74.0000
1127	2016-03-21 18:46:00	1	3.7000	42.0000
1128	2016-03-21 18:47:00	1	29.6000	45.0000
1129	2016-03-21 18:48:00	1	-10.0000	48.0000
1130	2016-03-21 18:49:00	1	24.3000	40.0000
1131	2016-03-21 18:50:00	1	2.0000	59.0000
1132	2016-03-21 18:51:00	1	28.0000	46.0000
1133	2016-03-21 18:52:00	1	-6.9000	51.0000
1134	2016-03-21 18:53:00	1	8.0000	67.0000
1135	2016-03-21 18:54:00	1	-0.6000	43.0000
1136	2016-03-21 18:55:00	1	-6.1000	75.0000
1137	2016-03-21 18:56:00	1	16.1000	53.0000
1138	2016-03-21 18:57:00	1	-6.0000	40.0000
1139	2016-03-21 18:58:00	1	-5.9000	63.0000
1140	2016-03-21 18:59:00	1	26.6000	43.0000
1141	2016-03-21 19:00:00	1	-3.4000	55.0000
1142	2016-03-21 19:01:00	1	-6.5000	70.0000
1143	2016-03-21 19:02:00	1	3.5000	72.0000
1144	2016-03-21 19:03:00	1	17.7000	57.0000
1145	2016-03-21 19:04:00	1	29.1000	74.0000
1146	2016-03-21 19:05:00	1	3.0000	53.0000
1147	2016-03-21 19:06:00	1	2.4000	57.0000
1148	2016-03-21 19:07:00	1	23.0000	50.0000
1149	2016-03-21 19:08:00	1	-5.1000	69.0000
1150	2016-03-21 19:09:00	1	-0.9000	45.0000
1151	2016-03-21 19:10:00	1	27.5000	65.0000
1152	2016-03-21 19:11:00	1	-9.1000	62.0000
1153	2016-03-21 19:12:00	1	16.6000	72.0000
1154	2016-03-21 19:13:00	1	16.0000	63.0000
1155	2016-03-21 19:14:00	1	26.5000	54.0000
1156	2016-03-21 19:15:00	1	7.6000	44.0000
1157	2016-03-21 19:16:00	1	3.8000	42.0000
1158	2016-03-21 19:17:00	1	13.4000	47.0000
1159	2016-03-21 19:18:00	1	14.2000	69.0000
1160	2016-03-21 19:19:00	1	-9.2000	74.0000
1161	2016-03-21 19:20:00	1	23.2000	61.0000
1162	2016-03-21 19:21:00	1	24.4000	57.0000
1163	2016-03-21 19:22:00	1	14.9000	67.0000
1164	2016-03-21 19:23:00	1	11.2000	47.0000
1165	2016-03-21 19:24:00	1	28.3000	43.0000
1166	2016-03-21 19:25:00	1	-5.9000	68.0000
1167	2016-03-21 19:26:00	1	-6.7000	72.0000
1168	2016-03-21 19:27:00	1	9.5000	47.0000
1169	2016-03-21 19:28:00	1	-0.1000	53.0000
1170	2016-03-21 19:29:00	1	10.6000	61.0000
1171	2016-03-21 19:30:00	1	18.2000	76.0000
1172	2016-03-21 19:31:00	1	-0.5000	56.0000
1173	2016-03-21 19:32:00	1	9.3000	79.0000
1174	2016-03-21 19:33:00	1	19.3000	72.0000
1175	2016-03-21 19:34:00	1	-6.0000	47.0000
1176	2016-03-21 19:35:00	1	16.8000	72.0000
1177	2016-03-21 19:36:00	1	-6.0000	74.0000
1178	2016-03-21 19:37:00	1	-7.2000	67.0000
1179	2016-03-21 19:38:00	1	-1.5000	54.0000
1180	2016-03-21 19:39:00	1	8.7000	57.0000
1181	2016-03-21 19:40:00	1	4.3000	46.0000
1182	2016-03-21 19:41:00	1	-7.3000	46.0000
1183	2016-03-21 19:42:00	1	17.7000	54.0000
1184	2016-03-21 19:43:00	1	-2.4000	44.0000
1185	2016-03-21 19:44:00	1	17.7000	43.0000
1186	2016-03-21 19:45:00	1	-6.0000	74.0000
1187	2016-03-21 19:46:00	1	16.4000	49.0000
1188	2016-03-21 19:47:00	1	7.9000	57.0000
1189	2016-03-21 19:48:00	1	-3.5000	53.0000
1190	2016-03-21 19:49:00	1	-0.7000	57.0000
1191	2016-03-21 19:50:00	1	27.5000	56.0000
1192	2016-03-21 19:51:00	1	-2.3000	68.0000
1193	2016-03-21 19:52:00	1	7.2000	77.0000
1194	2016-03-21 19:53:00	1	20.4000	51.0000
1195	2016-03-21 19:54:00	1	24.6000	49.0000
1196	2016-03-21 19:55:00	1	22.6000	49.0000
1197	2016-03-21 19:56:00	1	21.8000	52.0000
1198	2016-03-21 19:57:00	1	16.6000	54.0000
1199	2016-03-21 19:58:00	1	7.5000	67.0000
1200	2016-03-21 19:59:00	1	7.2000	53.0000
1201	2016-03-21 20:00:00	1	12.4000	62.0000
1202	2016-03-21 20:01:00	1	11.1000	49.0000
1203	2016-03-21 20:02:00	1	24.8000	56.0000
1204	2016-03-21 20:03:00	1	4.6000	40.0000
1205	2016-03-21 20:04:00	1	-3.7000	54.0000
1206	2016-03-21 20:05:00	1	1.8000	48.0000
1207	2016-03-21 20:06:00	1	9.9000	46.0000
1208	2016-03-21 20:07:00	1	-4.7000	40.0000
1209	2016-03-21 20:08:00	1	20.1000	72.0000
1210	2016-03-21 20:09:00	1	12.8000	54.0000
1211	2016-03-21 20:10:00	1	-5.3000	78.0000
1212	2016-03-21 20:11:00	1	23.6000	76.0000
1213	2016-03-21 20:12:00	1	0.6000	58.0000
1214	2016-03-21 20:13:00	1	6.1000	75.0000
1215	2016-03-21 20:14:00	1	4.4000	47.0000
1216	2016-03-21 20:15:00	1	23.2000	76.0000
1217	2016-03-21 20:16:00	1	4.5000	53.0000
1218	2016-03-21 20:17:00	1	-4.4000	61.0000
1219	2016-03-21 20:18:00	1	3.4000	70.0000
1220	2016-03-21 20:19:00	1	0.7000	78.0000
1221	2016-03-21 20:20:00	1	-6.0000	78.0000
1222	2016-03-21 20:21:00	1	13.5000	54.0000
1223	2016-03-21 20:22:00	1	-8.0000	43.0000
1224	2016-03-21 20:23:00	1	11.0000	67.0000
1225	2016-03-21 20:24:00	1	14.5000	64.0000
1226	2016-03-21 20:25:00	1	6.9000	75.0000
1227	2016-03-21 20:26:00	1	9.1000	45.0000
1228	2016-03-21 20:27:00	1	15.7000	51.0000
1229	2016-03-21 20:28:00	1	20.8000	40.0000
1230	2016-03-21 20:29:00	1	7.8000	49.0000
1231	2016-03-21 20:30:00	1	25.1000	53.0000
1232	2016-03-21 20:31:00	1	-8.1000	77.0000
1233	2016-03-21 20:32:00	1	15.4000	49.0000
1234	2016-03-21 20:33:00	1	9.0000	56.0000
1235	2016-03-21 20:34:00	1	17.7000	79.0000
1236	2016-03-21 20:35:00	1	8.5000	43.0000
1237	2016-03-21 20:36:00	1	2.2000	60.0000
1238	2016-03-21 20:37:00	1	5.6000	41.0000
1239	2016-03-21 20:38:00	1	20.8000	72.0000
1240	2016-03-21 20:39:00	1	-3.6000	78.0000
1241	2016-03-21 20:40:00	1	-9.7000	50.0000
1242	2016-03-21 20:41:00	1	-5.5000	78.0000
1243	2016-03-21 20:42:00	1	23.8000	63.0000
1244	2016-03-21 20:43:00	1	-0.8000	78.0000
1245	2016-03-21 20:44:00	1	22.1000	55.0000
1246	2016-03-21 20:45:00	1	19.7000	51.0000
1247	2016-03-21 20:46:00	1	28.0000	71.0000
1248	2016-03-21 20:47:00	1	26.9000	54.0000
1249	2016-03-21 20:48:00	1	29.1000	66.0000
1250	2016-03-21 20:49:00	1	12.2000	79.0000
1251	2016-03-21 20:50:00	1	-4.3000	44.0000
1252	2016-03-21 20:51:00	1	8.5000	62.0000
1253	2016-03-21 20:52:00	1	-7.3000	59.0000
1254	2016-03-21 20:53:00	1	22.0000	67.0000
1255	2016-03-21 20:54:00	1	20.5000	72.0000
1256	2016-03-21 20:55:00	1	-1.1000	67.0000
1257	2016-03-21 20:56:00	1	11.7000	57.0000
1258	2016-03-21 20:57:00	1	0.3000	78.0000
1259	2016-03-21 20:58:00	1	-6.3000	74.0000
1260	2016-03-21 20:59:00	1	-9.9000	64.0000
1261	2016-03-21 21:00:00	1	-3.5000	43.0000
1262	2016-03-21 21:01:00	1	13.1000	56.0000
1263	2016-03-21 21:02:00	1	11.5000	42.0000
1264	2016-03-21 21:03:00	1	17.9000	54.0000
1265	2016-03-21 21:04:00	1	26.0000	41.0000
1266	2016-03-21 21:05:00	1	-2.6000	52.0000
1267	2016-03-21 21:06:00	1	0.7000	55.0000
1268	2016-03-21 21:07:00	1	9.5000	49.0000
1269	2016-03-21 21:08:00	1	9.9000	77.0000
1270	2016-03-21 21:09:00	1	-3.1000	45.0000
1271	2016-03-21 21:10:00	1	-0.1000	42.0000
1272	2016-03-21 21:11:00	1	-8.7000	51.0000
1273	2016-03-21 21:12:00	1	19.2000	57.0000
1274	2016-03-21 21:13:00	1	-2.9000	59.0000
1275	2016-03-21 21:14:00	1	21.1000	45.0000
1276	2016-03-21 21:15:00	1	18.7000	40.0000
1277	2016-03-21 21:16:00	1	27.2000	57.0000
1278	2016-03-21 21:17:00	1	-8.0000	42.0000
1279	2016-03-21 21:18:00	1	21.9000	47.0000
1280	2016-03-21 21:19:00	1	29.3000	47.0000
1281	2016-03-21 21:20:00	1	29.9000	69.0000
1282	2016-03-21 21:21:00	1	19.6000	53.0000
1283	2016-03-21 21:22:00	1	22.6000	73.0000
1284	2016-03-21 21:23:00	1	14.0000	57.0000
1285	2016-03-21 21:24:00	1	10.6000	79.0000
1286	2016-03-21 21:25:00	1	12.9000	79.0000
1287	2016-03-21 21:26:00	1	-3.2000	54.0000
1288	2016-03-21 21:27:00	1	12.1000	40.0000
1289	2016-03-21 21:28:00	1	25.7000	59.0000
1290	2016-03-21 21:29:00	1	18.9000	63.0000
1291	2016-03-21 21:30:00	1	26.5000	42.0000
1292	2016-03-21 21:31:00	1	14.3000	71.0000
1293	2016-03-21 21:32:00	1	19.4000	59.0000
1294	2016-03-21 21:33:00	1	2.4000	78.0000
1295	2016-03-21 21:34:00	1	6.2000	69.0000
1296	2016-03-21 21:35:00	1	-0.9000	54.0000
1297	2016-03-21 21:36:00	1	8.4000	64.0000
1298	2016-03-21 21:37:00	1	16.8000	41.0000
1299	2016-03-21 21:38:00	1	-2.3000	49.0000
1300	2016-03-21 21:39:00	1	13.4000	47.0000
1301	2016-03-21 21:40:00	1	-8.2000	61.0000
1302	2016-03-21 21:41:00	1	8.8000	69.0000
1303	2016-03-21 21:42:00	1	20.4000	56.0000
1304	2016-03-21 21:43:00	1	-5.5000	47.0000
1305	2016-03-21 21:44:00	1	20.2000	47.0000
1306	2016-03-21 21:45:00	1	2.9000	59.0000
1307	2016-03-21 21:46:00	1	0.9000	72.0000
1308	2016-03-21 21:47:00	1	10.4000	48.0000
1309	2016-03-21 21:48:00	1	13.6000	43.0000
1310	2016-03-21 21:49:00	1	11.6000	56.0000
1311	2016-03-21 21:50:00	1	-5.6000	51.0000
1312	2016-03-21 21:51:00	1	6.0000	70.0000
1313	2016-03-21 21:52:00	1	19.4000	56.0000
1314	2016-03-21 21:53:00	1	23.8000	52.0000
1315	2016-03-21 21:54:00	1	3.6000	70.0000
1316	2016-03-21 21:55:00	1	15.4000	74.0000
1317	2016-03-21 21:56:00	1	13.4000	64.0000
1318	2016-03-21 21:57:00	1	13.9000	65.0000
1319	2016-03-21 21:58:00	1	-4.8000	51.0000
1320	2016-03-21 21:59:00	1	-10.0000	56.0000
1321	2016-03-21 22:00:00	1	11.7000	41.0000
1322	2016-03-21 22:01:00	1	12.1000	47.0000
1323	2016-03-21 22:02:00	1	0.2000	64.0000
1324	2016-03-21 22:03:00	1	22.9000	63.0000
1325	2016-03-21 22:04:00	1	25.3000	61.0000
1326	2016-03-21 22:05:00	1	23.6000	60.0000
1327	2016-03-21 22:06:00	1	-4.8000	49.0000
1328	2016-03-21 22:07:00	1	12.5000	47.0000
1329	2016-03-21 22:08:00	1	2.4000	62.0000
1330	2016-03-21 22:09:00	1	21.7000	51.0000
1331	2016-03-21 22:10:00	1	23.4000	78.0000
1332	2016-03-21 22:11:00	1	-8.5000	42.0000
1333	2016-03-21 22:12:00	1	11.4000	47.0000
1334	2016-03-21 22:13:00	1	20.7000	63.0000
1335	2016-03-21 22:14:00	1	3.7000	59.0000
1336	2016-03-21 22:15:00	1	11.9000	76.0000
1337	2016-03-21 22:16:00	1	-6.4000	52.0000
1338	2016-03-21 22:17:00	1	18.1000	53.0000
1339	2016-03-21 22:18:00	1	-3.6000	58.0000
1340	2016-03-21 22:19:00	1	-2.5000	64.0000
1341	2016-03-21 22:20:00	1	25.5000	76.0000
1342	2016-03-21 22:21:00	1	-8.6000	72.0000
1343	2016-03-21 22:22:00	1	0.7000	74.0000
1344	2016-03-21 22:23:00	1	25.2000	50.0000
1345	2016-03-21 22:24:00	1	-9.8000	79.0000
1346	2016-03-21 22:25:00	1	-0.8000	47.0000
1347	2016-03-21 22:26:00	1	-5.9000	45.0000
1348	2016-03-21 22:27:00	1	0.5000	59.0000
1349	2016-03-21 22:28:00	1	26.1000	76.0000
1350	2016-03-21 22:29:00	1	2.0000	49.0000
1351	2016-03-21 22:30:00	1	21.9000	59.0000
1352	2016-03-21 22:31:00	1	-4.8000	76.0000
1353	2016-03-21 22:32:00	1	27.8000	67.0000
1354	2016-03-21 22:33:00	1	-0.8000	48.0000
1355	2016-03-21 22:34:00	1	4.2000	66.0000
1356	2016-03-21 22:35:00	1	-4.1000	45.0000
1357	2016-03-21 22:36:00	1	7.8000	77.0000
1358	2016-03-21 22:37:00	1	0.4000	47.0000
1359	2016-03-21 22:38:00	1	21.2000	57.0000
1360	2016-03-21 22:39:00	1	1.7000	67.0000
1361	2016-03-21 22:40:00	1	22.5000	58.0000
1362	2016-03-21 22:41:00	1	15.1000	52.0000
1363	2016-03-21 22:42:00	1	21.6000	44.0000
1364	2016-03-21 22:43:00	1	12.0000	55.0000
1365	2016-03-21 22:44:00	1	26.8000	51.0000
1366	2016-03-21 22:45:00	1	27.5000	55.0000
1367	2016-03-21 22:46:00	1	17.9000	48.0000
1368	2016-03-21 22:47:00	1	14.2000	43.0000
1369	2016-03-21 22:48:00	1	26.0000	79.0000
1370	2016-03-21 22:49:00	1	19.9000	41.0000
1371	2016-03-21 22:50:00	1	0.1000	64.0000
1372	2016-03-21 22:51:00	1	9.9000	47.0000
1373	2016-03-21 22:52:00	1	-6.8000	63.0000
1374	2016-03-21 22:53:00	1	6.4000	71.0000
1375	2016-03-21 22:54:00	1	25.9000	51.0000
1376	2016-03-21 22:55:00	1	15.9000	75.0000
1377	2016-03-21 22:56:00	1	-0.9000	73.0000
1378	2016-03-21 22:57:00	1	15.0000	72.0000
1379	2016-03-21 22:58:00	1	-3.5000	77.0000
1380	2016-03-21 22:59:00	1	18.4000	56.0000
1381	2016-03-21 23:00:00	1	-9.0000	51.0000
1382	2016-03-21 23:01:00	1	21.9000	59.0000
1383	2016-03-21 23:02:00	1	18.6000	62.0000
1384	2016-03-21 23:03:00	1	4.6000	74.0000
1385	2016-03-21 23:04:00	1	-0.5000	72.0000
1386	2016-03-21 23:05:00	1	24.8000	46.0000
1387	2016-03-21 23:06:00	1	-9.6000	61.0000
1388	2016-03-21 23:07:00	1	-2.5000	76.0000
1389	2016-03-21 23:08:00	1	-4.9000	66.0000
1390	2016-03-21 23:09:00	1	28.0000	44.0000
1391	2016-03-21 23:10:00	1	2.0000	46.0000
1392	2016-03-21 23:11:00	1	19.4000	46.0000
1393	2016-03-21 23:12:00	1	24.8000	45.0000
1394	2016-03-21 23:13:00	1	11.8000	56.0000
1395	2016-03-21 23:14:00	1	11.5000	45.0000
1396	2016-03-21 23:15:00	1	-5.5000	70.0000
1397	2016-03-21 23:16:00	1	26.2000	44.0000
1398	2016-03-21 23:17:00	1	1.4000	54.0000
1399	2016-03-21 23:18:00	1	2.6000	51.0000
1400	2016-03-21 23:19:00	1	-0.6000	46.0000
1401	2016-03-21 23:20:00	1	20.4000	44.0000
1402	2016-03-21 23:21:00	1	-8.4000	59.0000
1403	2016-03-21 23:22:00	1	9.0000	65.0000
1404	2016-03-21 23:23:00	1	24.3000	50.0000
1405	2016-03-21 23:24:00	1	23.0000	63.0000
1406	2016-03-21 23:25:00	1	15.0000	49.0000
1407	2016-03-21 23:26:00	1	6.1000	73.0000
1408	2016-03-21 23:27:00	1	16.2000	49.0000
1409	2016-03-21 23:28:00	1	18.9000	53.0000
1410	2016-03-21 23:29:00	1	2.1000	61.0000
1411	2016-03-21 23:30:00	1	8.3000	58.0000
1412	2016-03-21 23:31:00	1	22.8000	53.0000
1413	2016-03-21 23:32:00	1	3.1000	40.0000
1414	2016-03-21 23:33:00	1	29.3000	47.0000
1415	2016-03-21 23:34:00	1	20.1000	57.0000
1416	2016-03-21 23:35:00	1	-2.2000	74.0000
1417	2016-03-21 23:36:00	1	2.9000	65.0000
1418	2016-03-21 23:37:00	1	1.3000	67.0000
1419	2016-03-21 23:38:00	1	8.5000	49.0000
1420	2016-03-21 23:39:00	1	5.9000	41.0000
1421	2016-03-21 23:40:00	1	27.9000	52.0000
1422	2016-03-21 23:41:00	1	6.6000	41.0000
1423	2016-03-21 23:42:00	1	5.3000	44.0000
1424	2016-03-21 23:43:00	1	14.9000	64.0000
1425	2016-03-21 23:44:00	1	0.8000	56.0000
1426	2016-03-21 23:45:00	1	4.6000	55.0000
1427	2016-03-21 23:46:00	1	3.7000	77.0000
1428	2016-03-21 23:47:00	1	-6.4000	55.0000
1429	2016-03-21 23:48:00	1	1.6000	76.0000
1430	2016-03-21 23:49:00	1	2.6000	48.0000
1431	2016-03-21 23:50:00	1	1.5000	54.0000
1432	2016-03-21 23:51:00	1	12.3000	74.0000
1433	2016-03-21 23:52:00	1	19.7000	75.0000
1434	2016-03-21 23:53:00	1	6.2000	49.0000
1435	2016-03-21 23:54:00	1	29.2000	59.0000
1436	2016-03-21 23:55:00	1	9.7000	76.0000
1437	2016-03-21 23:56:00	1	23.0000	40.0000
1438	2016-03-21 23:57:00	1	1.2000	57.0000
1439	2016-03-21 23:58:00	1	29.1000	48.0000
1440	2016-03-21 23:59:00	1	2.5000	41.0000
\.


--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('misurazioni_id_misurazione_seq', 1440, true);


--
-- Name: programma_id_programma_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('programma_id_programma_seq', 31, true);


--
-- Data for Name: programmi; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY programmi (id_programma, nome_programma, descrizione_programma, temperature_rif, sensore_rif) FROM stdin;
31	Lavorativo	Temperatura alta solo nei periodi in cui siamo in casa	{18.0000,19.0000,20.0000,22.0000}	0
\.


--
-- Data for Name: sensori; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY sensori (id_sensore, nome_sensore, descrizione, posizione, abilitato, incluso_in_media, id_driver, ultimo_aggiornamento) FROM stdin;
1	Test	Sensore di test	\N	t	t	1	2016-03-22 07:36:58.833775
\.


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('sensori_id_sensore_seq', 1, true);


--
-- Data for Name: situazione; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY situazione (data_ora, id_sensore, temperatura, umidita, tendenza_temperatura, tendenza_umidita) FROM stdin;
2016-03-21 23:59:00	1	2.5000	41.0000	\N	\N
\.


--
-- Name: dati_giornalieri_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT dati_giornalieri_pkey PRIMARY KEY (data, id_sensore);


--
-- Name: dettaglio_programma_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dettaglio_programma
    ADD CONSTRAINT dettaglio_programma_pkey PRIMARY KEY (id_programma, giorno, ora);


--
-- Name: driver_sensori_nome_driver_key; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_nome_driver_key UNIQUE (nome_driver);


--
-- Name: driver_sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_pkey PRIMARY KEY (id_driver);


--
-- Name: impostazioni_pk; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY impostazioni
    ADD CONSTRAINT impostazioni_pk PRIMARY KEY (nome);


--
-- Name: misurazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT misurazioni_pkey PRIMARY KEY (id_misurazione);


--
-- Name: programma_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT programma_pkey PRIMARY KEY (id_programma);


--
-- Name: sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY sensori
    ADD CONSTRAINT sensori_pkey PRIMARY KEY (id_sensore);


--
-- Name: situazione_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY situazione
    ADD CONSTRAINT situazione_pkey PRIMARY KEY (id_sensore);


--
-- Name: un_data_sensore; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT un_data_sensore UNIQUE (data_ora, id_sensore);


--
-- Name: un_nome_programma; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT un_nome_programma UNIQUE (nome_programma);


--
-- Name: un_nome_sensore; Type: INDEX; Schema: public; Owner: smac
--

CREATE UNIQUE INDEX un_nome_sensore ON sensori USING btree (nome_sensore);


--
-- Name: aggiornamento_situazione; Type: TRIGGER; Schema: public; Owner: smac
--

CREATE TRIGGER aggiornamento_situazione AFTER INSERT ON misurazioni FOR EACH ROW WHEN (((new.temperatura IS NOT NULL) OR (new.umidita IS NOT NULL))) EXECUTE PROCEDURE aggiorna_situazione();


--
-- Name: dettaglio_programma_id_programma_fkey; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dettaglio_programma
    ADD CONSTRAINT dettaglio_programma_id_programma_fkey FOREIGN KEY (id_programma) REFERENCES programmi(id_programma);


--
-- Name: fk_driver_sensore; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY sensori
    ADD CONSTRAINT fk_driver_sensore FOREIGN KEY (id_driver) REFERENCES driver_sensori(id_driver);


--
-- Name: fk_situazione_sensore; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY situazione
    ADD CONSTRAINT fk_situazione_sensore FOREIGN KEY (id_sensore) REFERENCES sensori(id_sensore);


--
-- Name: fk_synop_temp_max; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_synop_temp_max FOREIGN KEY (id_synop_temp_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_synop_temp_min; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_synop_temp_min FOREIGN KEY (id_synop_temp_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_syrep_temp_max; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_syrep_temp_max FOREIGN KEY (id_syrep_temp_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_syrep_temp_min; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_syrep_temp_min FOREIGN KEY (id_syrep_temp_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_umidita_min; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_umidita_min FOREIGN KEY (id_umidita_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: id_umidita_max; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT id_umidita_max FOREIGN KEY (id_umidita_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: pk_misurazione_sensore; Type: FK CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT pk_misurazione_sensore FOREIGN KEY (id_sensore) REFERENCES sensori(id_sensore);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

