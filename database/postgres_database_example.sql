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
	nome character varying(64),
	descrizione character varying(256),
	posizione point,
	abilitato boolean,
	incluso_in_media boolean,
	parametri character varying(64),
	id_driver smallint,
	nome_driver character varying(16),
	parametri_driver character varying(64),
	ultimo_aggiornamento timestamp without time zone
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
            SELECT nome INTO nome_sensore_rif from elenco_sensori(null) where id = id_sensore_rif;

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
            SELECT nome INTO nome_sensore_rif from elenco_sensori(null) where id = id_sensore_rif;

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
                      e.nome
                 FROM programmi p
            LEFT JOIN elenco_sensori(null) AS e
                   ON e.id = p.sensore_rif
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
-- Name: elenco_sensori(boolean); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION elenco_sensori(stato boolean DEFAULT NULL::boolean) RETURNS SETOF parametri_sensore
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
                   NULL::varchar(64),
                   NULL::smallint,
                   NULL::varchar(16),
                   NULL::varchar(64),
                   NOW()::Timestamp Without Time Zone;
     END IF;

     RETURN QUERY
           SELECT s.id_sensore,
                  s.nome_sensore,
                  s.descrizione,
                  s.posizione,
                  s.abilitato,
                  s.incluso_in_media,
                  s.parametri,
                  s.id_driver,
                  d.nome,
                  d.parametri,
                  s.ultimo_aggiornamento
             FROM sensori s
        LEFT JOIN driver_sensori d
               ON s.id_driver = d.id
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
    id smallint NOT NULL,
    nome character varying(16),
    parametri character varying(64)
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

ALTER SEQUENCE driver_sensori_id_driver_seq OWNED BY driver_sensori.id;


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
    ultimo_aggiornamento timestamp without time zone,
    parametri character varying(64)
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
-- Name: id; Type: DEFAULT; Schema: public; Owner: smac
--

ALTER TABLE ONLY driver_sensori ALTER COLUMN id SET DEFAULT nextval('driver_sensori_id_driver_seq'::regclass);


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

COPY driver_sensori (id, nome, parametri) FROM stdin;
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
programma_attuale	0
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
1441	2016-03-23 00:00:00	1	18.4000	56.0000
1442	2016-03-23 00:01:00	1	11.0000	59.0000
1443	2016-03-23 00:02:00	1	29.1000	58.0000
1444	2016-03-23 00:03:00	1	0.0000	62.0000
1445	2016-03-23 00:04:00	1	6.2000	49.0000
1446	2016-03-23 00:05:00	1	-3.7000	62.0000
1447	2016-03-23 00:06:00	1	5.1000	73.0000
1448	2016-03-23 00:07:00	1	6.2000	72.0000
1449	2016-03-23 00:08:00	1	21.3000	58.0000
1450	2016-03-23 00:09:00	1	-1.2000	78.0000
1451	2016-03-23 00:10:00	1	26.1000	58.0000
1452	2016-03-23 00:11:00	1	-0.8000	61.0000
1453	2016-03-23 00:12:00	1	22.3000	69.0000
1454	2016-03-23 00:13:00	1	20.0000	78.0000
1455	2016-03-23 00:14:00	1	13.1000	58.0000
1456	2016-03-23 00:15:00	1	20.9000	41.0000
1457	2016-03-23 00:16:00	1	17.4000	69.0000
1458	2016-03-23 00:17:00	1	-9.7000	59.0000
1459	2016-03-23 00:18:00	1	17.4000	57.0000
1460	2016-03-23 00:19:00	1	-3.9000	68.0000
1461	2016-03-23 00:20:00	1	6.8000	69.0000
1462	2016-03-23 00:21:00	1	12.5000	51.0000
1463	2016-03-23 00:22:00	1	8.2000	44.0000
1464	2016-03-23 00:23:00	1	21.8000	57.0000
1465	2016-03-23 00:24:00	1	4.4000	44.0000
1466	2016-03-23 00:25:00	1	15.5000	41.0000
1467	2016-03-23 00:26:00	1	14.2000	67.0000
1468	2016-03-23 00:27:00	1	13.7000	54.0000
1469	2016-03-23 00:28:00	1	-9.0000	53.0000
1470	2016-03-23 00:29:00	1	21.7000	58.0000
1471	2016-03-23 00:30:00	1	26.8000	62.0000
1472	2016-03-23 00:31:00	1	25.6000	46.0000
1473	2016-03-23 00:32:00	1	24.4000	40.0000
1474	2016-03-23 00:33:00	1	0.7000	58.0000
1475	2016-03-23 00:34:00	1	-3.8000	46.0000
1476	2016-03-23 00:35:00	1	15.3000	62.0000
1477	2016-03-23 00:36:00	1	19.2000	57.0000
1478	2016-03-23 00:37:00	1	4.8000	77.0000
1479	2016-03-23 00:38:00	1	-3.4000	77.0000
1480	2016-03-23 00:39:00	1	6.9000	62.0000
1481	2016-03-23 00:40:00	1	-2.9000	68.0000
1482	2016-03-23 00:41:00	1	21.6000	63.0000
1483	2016-03-23 00:42:00	1	27.1000	66.0000
1484	2016-03-23 00:43:00	1	-2.2000	52.0000
1485	2016-03-23 00:44:00	1	19.1000	48.0000
1486	2016-03-23 00:45:00	1	12.3000	51.0000
1487	2016-03-23 00:46:00	1	12.0000	50.0000
1488	2016-03-23 00:47:00	1	0.0000	42.0000
1489	2016-03-23 00:48:00	1	3.8000	62.0000
1490	2016-03-23 00:49:00	1	28.1000	46.0000
1491	2016-03-23 00:50:00	1	27.5000	46.0000
1492	2016-03-23 00:51:00	1	-7.1000	43.0000
1493	2016-03-23 00:52:00	1	21.3000	42.0000
1494	2016-03-23 00:53:00	1	24.0000	64.0000
1495	2016-03-23 00:54:00	1	14.2000	53.0000
1496	2016-03-23 00:55:00	1	8.9000	79.0000
1497	2016-03-23 00:56:00	1	3.4000	49.0000
1498	2016-03-23 00:57:00	1	12.7000	77.0000
1499	2016-03-23 00:58:00	1	15.9000	59.0000
1500	2016-03-23 00:59:00	1	-1.4000	53.0000
1501	2016-03-23 01:00:00	1	20.0000	79.0000
1502	2016-03-23 01:01:00	1	-9.2000	57.0000
1503	2016-03-23 01:02:00	1	-1.2000	41.0000
1504	2016-03-23 01:03:00	1	18.3000	58.0000
1505	2016-03-23 01:04:00	1	21.5000	79.0000
1506	2016-03-23 01:05:00	1	-7.5000	71.0000
1507	2016-03-23 01:06:00	1	-0.1000	73.0000
1508	2016-03-23 01:07:00	1	5.6000	68.0000
1509	2016-03-23 01:08:00	1	13.0000	53.0000
1510	2016-03-23 01:09:00	1	29.2000	73.0000
1511	2016-03-23 01:10:00	1	10.6000	78.0000
1512	2016-03-23 01:11:00	1	28.6000	67.0000
1513	2016-03-23 01:12:00	1	18.7000	74.0000
1514	2016-03-23 01:13:00	1	-5.6000	41.0000
1515	2016-03-23 01:14:00	1	1.7000	53.0000
1516	2016-03-23 01:15:00	1	19.5000	40.0000
1517	2016-03-23 01:16:00	1	-6.0000	59.0000
1518	2016-03-23 01:17:00	1	3.7000	61.0000
1519	2016-03-23 01:18:00	1	-9.0000	56.0000
1520	2016-03-23 01:19:00	1	25.4000	63.0000
1521	2016-03-23 01:20:00	1	18.4000	44.0000
1522	2016-03-23 01:21:00	1	11.5000	60.0000
1523	2016-03-23 01:22:00	1	-6.8000	68.0000
1524	2016-03-23 01:23:00	1	29.6000	51.0000
1525	2016-03-23 01:24:00	1	-3.3000	60.0000
1526	2016-03-23 01:25:00	1	23.4000	67.0000
1527	2016-03-23 01:26:00	1	6.9000	55.0000
1528	2016-03-23 01:27:00	1	11.2000	65.0000
1529	2016-03-23 01:28:00	1	3.2000	59.0000
1530	2016-03-23 01:29:00	1	10.0000	42.0000
1531	2016-03-23 01:30:00	1	28.8000	41.0000
1532	2016-03-23 01:31:00	1	16.6000	64.0000
1533	2016-03-23 01:32:00	1	29.7000	60.0000
1534	2016-03-23 01:33:00	1	5.6000	40.0000
1535	2016-03-23 01:34:00	1	-7.7000	65.0000
1536	2016-03-23 01:35:00	1	23.2000	51.0000
1537	2016-03-23 01:36:00	1	-1.2000	77.0000
1538	2016-03-23 01:37:00	1	19.0000	45.0000
1539	2016-03-23 01:38:00	1	1.8000	79.0000
1540	2016-03-23 01:39:00	1	28.2000	66.0000
1541	2016-03-23 01:40:00	1	17.4000	59.0000
1542	2016-03-23 01:41:00	1	-4.3000	56.0000
1543	2016-03-23 01:42:00	1	13.5000	47.0000
1544	2016-03-23 01:43:00	1	-0.2000	64.0000
1545	2016-03-23 01:44:00	1	2.6000	47.0000
1546	2016-03-23 01:45:00	1	11.6000	57.0000
1547	2016-03-23 01:46:00	1	29.3000	49.0000
1548	2016-03-23 01:47:00	1	4.1000	68.0000
1549	2016-03-23 01:48:00	1	-1.5000	67.0000
1550	2016-03-23 01:49:00	1	29.8000	65.0000
1551	2016-03-23 01:50:00	1	-9.3000	51.0000
1552	2016-03-23 01:51:00	1	-8.5000	41.0000
1553	2016-03-23 01:52:00	1	-2.3000	47.0000
1554	2016-03-23 01:53:00	1	11.5000	74.0000
1555	2016-03-23 01:54:00	1	9.2000	42.0000
1556	2016-03-23 01:55:00	1	28.0000	45.0000
1557	2016-03-23 01:56:00	1	1.2000	52.0000
1558	2016-03-23 01:57:00	1	0.7000	55.0000
1559	2016-03-23 01:58:00	1	20.6000	62.0000
1560	2016-03-23 01:59:00	1	21.4000	44.0000
1561	2016-03-23 02:00:00	1	0.3000	65.0000
1562	2016-03-23 02:01:00	1	4.6000	57.0000
1563	2016-03-23 02:02:00	1	11.2000	43.0000
1564	2016-03-23 02:03:00	1	-1.3000	43.0000
1565	2016-03-23 02:04:00	1	8.4000	73.0000
1566	2016-03-23 02:05:00	1	-9.5000	42.0000
1567	2016-03-23 02:06:00	1	-8.5000	44.0000
1568	2016-03-23 02:07:00	1	18.6000	53.0000
1569	2016-03-23 02:08:00	1	22.6000	49.0000
1570	2016-03-23 02:09:00	1	18.7000	57.0000
1571	2016-03-23 02:10:00	1	19.8000	47.0000
1572	2016-03-23 02:11:00	1	8.2000	52.0000
1573	2016-03-23 02:12:00	1	20.3000	63.0000
1574	2016-03-23 02:13:00	1	25.7000	78.0000
1575	2016-03-23 02:14:00	1	-0.5000	47.0000
1576	2016-03-23 02:15:00	1	14.2000	74.0000
1577	2016-03-23 02:16:00	1	-10.0000	64.0000
1578	2016-03-23 02:17:00	1	19.4000	46.0000
1579	2016-03-23 02:18:00	1	17.5000	76.0000
1580	2016-03-23 02:19:00	1	0.9000	57.0000
1581	2016-03-23 02:20:00	1	-3.5000	57.0000
1582	2016-03-23 02:21:00	1	15.0000	73.0000
1583	2016-03-23 02:22:00	1	3.4000	61.0000
1584	2016-03-23 02:23:00	1	7.1000	53.0000
1585	2016-03-23 02:24:00	1	13.8000	73.0000
1586	2016-03-23 02:25:00	1	7.6000	61.0000
1587	2016-03-23 02:26:00	1	22.4000	72.0000
1588	2016-03-23 02:27:00	1	4.6000	58.0000
1589	2016-03-23 02:28:00	1	14.8000	61.0000
1590	2016-03-23 02:29:00	1	-6.3000	59.0000
1591	2016-03-23 02:30:00	1	27.4000	79.0000
1592	2016-03-23 02:31:00	1	4.0000	60.0000
1593	2016-03-23 02:32:00	1	16.6000	64.0000
1594	2016-03-23 02:33:00	1	8.7000	49.0000
1595	2016-03-23 02:34:00	1	-8.6000	55.0000
1596	2016-03-23 02:35:00	1	10.0000	49.0000
1597	2016-03-23 02:36:00	1	-9.1000	45.0000
1598	2016-03-23 02:37:00	1	5.8000	73.0000
1599	2016-03-23 02:38:00	1	8.7000	67.0000
1600	2016-03-23 02:39:00	1	10.2000	76.0000
1601	2016-03-23 02:40:00	1	28.7000	76.0000
1602	2016-03-23 02:41:00	1	6.1000	59.0000
1603	2016-03-23 02:42:00	1	23.7000	51.0000
1604	2016-03-23 02:43:00	1	3.8000	62.0000
1605	2016-03-23 02:44:00	1	-9.0000	54.0000
1606	2016-03-23 02:45:00	1	2.7000	40.0000
1607	2016-03-23 02:46:00	1	-4.7000	75.0000
1608	2016-03-23 02:47:00	1	26.0000	75.0000
1609	2016-03-23 02:48:00	1	20.1000	45.0000
1610	2016-03-23 02:49:00	1	-4.0000	59.0000
1611	2016-03-23 02:50:00	1	-5.8000	51.0000
1612	2016-03-23 02:51:00	1	29.4000	73.0000
1613	2016-03-23 02:52:00	1	21.1000	50.0000
1614	2016-03-23 02:53:00	1	9.5000	61.0000
1615	2016-03-23 02:54:00	1	-2.0000	72.0000
1616	2016-03-23 02:55:00	1	2.3000	77.0000
1617	2016-03-23 02:56:00	1	27.5000	75.0000
1618	2016-03-23 02:57:00	1	27.7000	55.0000
1619	2016-03-23 02:58:00	1	9.1000	73.0000
1620	2016-03-23 02:59:00	1	-0.3000	58.0000
1621	2016-03-23 03:00:00	1	19.0000	78.0000
1622	2016-03-23 03:01:00	1	8.6000	59.0000
1623	2016-03-23 03:02:00	1	-0.9000	57.0000
1624	2016-03-23 03:03:00	1	16.2000	52.0000
1625	2016-03-23 03:04:00	1	19.2000	59.0000
1626	2016-03-23 03:05:00	1	20.7000	63.0000
1627	2016-03-23 03:06:00	1	8.3000	59.0000
1628	2016-03-23 03:07:00	1	28.6000	65.0000
1629	2016-03-23 03:08:00	1	-4.7000	42.0000
1630	2016-03-23 03:09:00	1	9.2000	45.0000
1631	2016-03-23 03:10:00	1	7.7000	43.0000
1632	2016-03-23 03:11:00	1	10.0000	62.0000
1633	2016-03-23 03:12:00	1	9.9000	58.0000
1634	2016-03-23 03:13:00	1	-3.6000	44.0000
1635	2016-03-23 03:14:00	1	19.3000	74.0000
1636	2016-03-23 03:15:00	1	9.1000	78.0000
1637	2016-03-23 03:16:00	1	28.5000	40.0000
1638	2016-03-23 03:17:00	1	2.6000	65.0000
1639	2016-03-23 03:18:00	1	2.3000	52.0000
1640	2016-03-23 03:19:00	1	-3.2000	40.0000
1641	2016-03-23 03:20:00	1	21.1000	48.0000
1642	2016-03-23 03:21:00	1	25.0000	61.0000
1643	2016-03-23 03:22:00	1	17.7000	59.0000
1644	2016-03-23 03:23:00	1	8.9000	75.0000
1645	2016-03-23 03:24:00	1	1.7000	72.0000
1646	2016-03-23 03:25:00	1	-3.8000	55.0000
1647	2016-03-23 03:26:00	1	19.7000	43.0000
1648	2016-03-23 03:27:00	1	-5.4000	73.0000
1649	2016-03-23 03:28:00	1	-6.1000	73.0000
1650	2016-03-23 03:29:00	1	-1.4000	71.0000
1651	2016-03-23 03:30:00	1	17.1000	79.0000
1652	2016-03-23 03:31:00	1	1.4000	79.0000
1653	2016-03-23 03:32:00	1	15.3000	66.0000
1654	2016-03-23 03:33:00	1	23.2000	56.0000
1655	2016-03-23 03:34:00	1	12.8000	40.0000
1656	2016-03-23 03:35:00	1	29.1000	49.0000
1657	2016-03-23 03:36:00	1	27.6000	79.0000
1658	2016-03-23 03:37:00	1	13.4000	55.0000
1659	2016-03-23 03:38:00	1	17.7000	56.0000
1660	2016-03-23 03:39:00	1	8.2000	60.0000
1661	2016-03-23 03:40:00	1	-9.7000	70.0000
1662	2016-03-23 03:41:00	1	18.7000	63.0000
1663	2016-03-23 03:42:00	1	0.5000	51.0000
1664	2016-03-23 03:43:00	1	29.6000	53.0000
1665	2016-03-23 03:44:00	1	-5.6000	73.0000
1666	2016-03-23 03:45:00	1	-2.4000	51.0000
1667	2016-03-23 03:46:00	1	25.8000	54.0000
1668	2016-03-23 03:47:00	1	7.1000	50.0000
1669	2016-03-23 03:48:00	1	-7.0000	73.0000
1670	2016-03-23 03:49:00	1	8.7000	59.0000
1671	2016-03-23 03:50:00	1	0.3000	42.0000
1672	2016-03-23 03:51:00	1	29.7000	41.0000
1673	2016-03-23 03:52:00	1	2.0000	58.0000
1674	2016-03-23 03:53:00	1	23.1000	40.0000
1675	2016-03-23 03:54:00	1	15.3000	45.0000
1676	2016-03-23 03:55:00	1	29.0000	43.0000
1677	2016-03-23 03:56:00	1	25.6000	75.0000
1678	2016-03-23 03:57:00	1	5.6000	49.0000
1679	2016-03-23 03:58:00	1	11.1000	42.0000
1680	2016-03-23 03:59:00	1	10.6000	51.0000
1681	2016-03-23 04:00:00	1	13.3000	47.0000
1682	2016-03-23 04:01:00	1	7.0000	66.0000
1683	2016-03-23 04:02:00	1	-2.8000	51.0000
1684	2016-03-23 04:03:00	1	-9.8000	41.0000
1685	2016-03-23 04:04:00	1	-5.7000	42.0000
1686	2016-03-23 04:05:00	1	26.0000	57.0000
1687	2016-03-23 04:06:00	1	26.8000	68.0000
1688	2016-03-23 04:07:00	1	12.5000	45.0000
1689	2016-03-23 04:08:00	1	8.8000	54.0000
1690	2016-03-23 04:09:00	1	-1.6000	60.0000
1691	2016-03-23 04:10:00	1	16.8000	45.0000
1692	2016-03-23 04:11:00	1	19.7000	54.0000
1693	2016-03-23 04:12:00	1	25.2000	49.0000
1694	2016-03-23 04:13:00	1	18.6000	46.0000
1695	2016-03-23 04:14:00	1	10.5000	45.0000
1696	2016-03-23 04:15:00	1	-8.2000	64.0000
1697	2016-03-23 04:16:00	1	27.3000	78.0000
1698	2016-03-23 04:17:00	1	12.9000	52.0000
1699	2016-03-23 04:18:00	1	2.8000	46.0000
1700	2016-03-23 04:19:00	1	4.6000	74.0000
1701	2016-03-23 04:20:00	1	-8.0000	53.0000
1702	2016-03-23 04:21:00	1	21.8000	52.0000
1703	2016-03-23 04:22:00	1	-3.7000	69.0000
1704	2016-03-23 04:23:00	1	-2.4000	47.0000
1705	2016-03-23 04:24:00	1	19.9000	62.0000
1706	2016-03-23 04:25:00	1	19.1000	42.0000
1707	2016-03-23 04:26:00	1	13.4000	50.0000
1708	2016-03-23 04:27:00	1	29.2000	66.0000
1709	2016-03-23 04:28:00	1	14.2000	59.0000
1710	2016-03-23 04:29:00	1	24.9000	48.0000
1711	2016-03-23 04:30:00	1	26.9000	48.0000
1712	2016-03-23 04:31:00	1	-1.4000	55.0000
1713	2016-03-23 04:32:00	1	5.3000	63.0000
1714	2016-03-23 04:33:00	1	28.7000	55.0000
1715	2016-03-23 04:34:00	1	4.7000	41.0000
1716	2016-03-23 04:35:00	1	-4.7000	78.0000
1717	2016-03-23 04:36:00	1	13.9000	60.0000
1718	2016-03-23 04:37:00	1	5.5000	55.0000
1719	2016-03-23 04:38:00	1	1.3000	66.0000
1720	2016-03-23 04:39:00	1	5.2000	72.0000
1721	2016-03-23 04:40:00	1	29.0000	48.0000
1722	2016-03-23 04:41:00	1	7.9000	74.0000
1723	2016-03-23 04:42:00	1	13.2000	50.0000
1724	2016-03-23 04:43:00	1	-9.0000	57.0000
1725	2016-03-23 04:44:00	1	-5.2000	52.0000
1726	2016-03-23 04:45:00	1	2.2000	72.0000
1727	2016-03-23 04:46:00	1	22.5000	58.0000
1728	2016-03-23 04:47:00	1	25.9000	45.0000
1729	2016-03-23 04:48:00	1	2.4000	55.0000
1730	2016-03-23 04:49:00	1	26.0000	71.0000
1731	2016-03-23 04:50:00	1	-2.1000	68.0000
1732	2016-03-23 04:51:00	1	-6.2000	71.0000
1733	2016-03-23 04:52:00	1	28.3000	78.0000
1734	2016-03-23 04:53:00	1	12.0000	77.0000
1735	2016-03-23 04:54:00	1	-7.7000	68.0000
1736	2016-03-23 04:55:00	1	0.8000	72.0000
1737	2016-03-23 04:56:00	1	-8.4000	43.0000
1738	2016-03-23 04:57:00	1	13.7000	74.0000
1739	2016-03-23 04:58:00	1	-4.3000	46.0000
1740	2016-03-23 04:59:00	1	22.2000	41.0000
1741	2016-03-23 05:00:00	1	10.6000	56.0000
1742	2016-03-23 05:01:00	1	2.3000	57.0000
1743	2016-03-23 05:02:00	1	15.3000	41.0000
1744	2016-03-23 05:03:00	1	10.9000	56.0000
1745	2016-03-23 05:04:00	1	-7.2000	62.0000
1746	2016-03-23 05:05:00	1	14.8000	53.0000
1747	2016-03-23 05:06:00	1	8.1000	55.0000
1748	2016-03-23 05:07:00	1	-7.4000	78.0000
1749	2016-03-23 05:08:00	1	-2.2000	50.0000
1750	2016-03-23 05:09:00	1	16.0000	77.0000
1751	2016-03-23 05:10:00	1	11.7000	44.0000
1752	2016-03-23 05:11:00	1	1.4000	54.0000
1753	2016-03-23 05:12:00	1	15.4000	76.0000
1754	2016-03-23 05:13:00	1	-1.9000	59.0000
1755	2016-03-23 05:14:00	1	9.9000	40.0000
1756	2016-03-23 05:15:00	1	-8.3000	60.0000
1757	2016-03-23 05:16:00	1	-5.2000	53.0000
1758	2016-03-23 05:17:00	1	3.7000	71.0000
1759	2016-03-23 05:18:00	1	12.2000	79.0000
1760	2016-03-23 05:19:00	1	17.9000	51.0000
1761	2016-03-23 05:20:00	1	1.5000	73.0000
1762	2016-03-23 05:21:00	1	25.8000	51.0000
1763	2016-03-23 05:22:00	1	-8.7000	68.0000
1764	2016-03-23 05:23:00	1	-4.0000	41.0000
1765	2016-03-23 05:24:00	1	12.9000	63.0000
1766	2016-03-23 05:25:00	1	9.2000	56.0000
1767	2016-03-23 05:26:00	1	18.7000	47.0000
1768	2016-03-23 05:27:00	1	17.9000	73.0000
1769	2016-03-23 05:28:00	1	15.8000	40.0000
1770	2016-03-23 05:29:00	1	-4.6000	45.0000
1771	2016-03-23 05:30:00	1	26.4000	53.0000
1772	2016-03-23 05:31:00	1	-3.7000	76.0000
1773	2016-03-23 05:32:00	1	11.1000	42.0000
1774	2016-03-23 05:33:00	1	21.4000	60.0000
1775	2016-03-23 05:34:00	1	4.5000	54.0000
1776	2016-03-23 05:35:00	1	18.3000	43.0000
1777	2016-03-23 05:36:00	1	21.9000	74.0000
1778	2016-03-23 05:37:00	1	5.6000	55.0000
1779	2016-03-23 05:38:00	1	12.3000	42.0000
1780	2016-03-23 05:39:00	1	-7.7000	61.0000
1781	2016-03-23 05:40:00	1	3.6000	74.0000
1782	2016-03-23 05:41:00	1	-0.2000	52.0000
1783	2016-03-23 05:42:00	1	2.1000	48.0000
1784	2016-03-23 05:43:00	1	6.5000	64.0000
1785	2016-03-23 05:44:00	1	23.8000	78.0000
1786	2016-03-23 05:45:00	1	-6.4000	67.0000
1787	2016-03-23 05:46:00	1	19.0000	53.0000
1788	2016-03-23 05:47:00	1	21.4000	77.0000
1789	2016-03-23 05:48:00	1	19.9000	70.0000
1790	2016-03-23 05:49:00	1	3.3000	56.0000
1791	2016-03-23 05:50:00	1	-8.0000	68.0000
1792	2016-03-23 05:51:00	1	20.5000	51.0000
1793	2016-03-23 05:52:00	1	15.6000	73.0000
1794	2016-03-23 05:53:00	1	17.1000	65.0000
1795	2016-03-23 05:54:00	1	17.7000	43.0000
1796	2016-03-23 05:55:00	1	3.2000	40.0000
1797	2016-03-23 05:56:00	1	0.9000	42.0000
1798	2016-03-23 05:57:00	1	-6.4000	58.0000
1799	2016-03-23 05:58:00	1	10.8000	78.0000
1800	2016-03-23 05:59:00	1	10.8000	57.0000
1801	2016-03-23 06:00:00	1	-8.0000	70.0000
1802	2016-03-23 06:01:00	1	-5.3000	47.0000
1803	2016-03-23 06:02:00	1	24.4000	68.0000
1804	2016-03-23 06:03:00	1	-9.0000	78.0000
1805	2016-03-23 06:04:00	1	8.9000	61.0000
1806	2016-03-23 06:05:00	1	18.7000	62.0000
1807	2016-03-23 06:06:00	1	6.0000	54.0000
1808	2016-03-23 06:07:00	1	4.9000	52.0000
1809	2016-03-23 06:08:00	1	15.2000	60.0000
1810	2016-03-23 06:09:00	1	-0.5000	61.0000
1811	2016-03-23 06:10:00	1	21.4000	42.0000
1812	2016-03-23 06:11:00	1	4.1000	40.0000
1813	2016-03-23 06:12:00	1	-4.3000	54.0000
1814	2016-03-23 06:13:00	1	15.2000	55.0000
1815	2016-03-23 06:14:00	1	27.8000	41.0000
1816	2016-03-23 06:15:00	1	-9.0000	68.0000
1817	2016-03-23 06:16:00	1	20.5000	77.0000
1818	2016-03-23 06:17:00	1	20.7000	74.0000
1819	2016-03-23 06:18:00	1	-8.1000	79.0000
1820	2016-03-23 06:19:00	1	-0.8000	42.0000
1821	2016-03-23 06:20:00	1	-3.9000	48.0000
1822	2016-03-23 06:21:00	1	-8.3000	50.0000
1823	2016-03-23 06:22:00	1	7.1000	58.0000
1824	2016-03-23 06:23:00	1	13.6000	48.0000
1825	2016-03-23 06:24:00	1	8.6000	59.0000
1826	2016-03-23 06:25:00	1	5.2000	61.0000
1827	2016-03-23 06:26:00	1	5.9000	51.0000
1828	2016-03-23 06:27:00	1	2.2000	46.0000
1829	2016-03-23 06:28:00	1	-3.0000	60.0000
1830	2016-03-23 06:29:00	1	-1.9000	76.0000
1831	2016-03-23 06:30:00	1	-6.6000	73.0000
1832	2016-03-23 06:31:00	1	-5.5000	51.0000
1833	2016-03-23 06:32:00	1	4.9000	60.0000
1834	2016-03-23 06:33:00	1	8.8000	54.0000
1835	2016-03-23 06:34:00	1	16.9000	59.0000
1836	2016-03-23 06:35:00	1	27.6000	59.0000
1837	2016-03-23 06:36:00	1	15.9000	40.0000
1838	2016-03-23 06:37:00	1	5.0000	48.0000
1839	2016-03-23 06:38:00	1	6.0000	52.0000
1840	2016-03-23 06:39:00	1	-4.8000	55.0000
1841	2016-03-23 06:40:00	1	21.8000	66.0000
1842	2016-03-23 06:41:00	1	-5.5000	53.0000
1843	2016-03-23 06:42:00	1	-0.2000	78.0000
1844	2016-03-23 06:43:00	1	19.3000	62.0000
1845	2016-03-23 06:44:00	1	4.1000	60.0000
1846	2016-03-23 06:45:00	1	11.6000	58.0000
1847	2016-03-23 06:46:00	1	-3.5000	43.0000
1848	2016-03-23 06:47:00	1	1.4000	62.0000
1849	2016-03-23 06:48:00	1	11.3000	55.0000
1850	2016-03-23 06:49:00	1	28.3000	41.0000
1851	2016-03-23 06:50:00	1	8.2000	52.0000
1852	2016-03-23 06:51:00	1	-8.8000	40.0000
1853	2016-03-23 06:52:00	1	25.3000	70.0000
1854	2016-03-23 06:53:00	1	-3.0000	69.0000
1855	2016-03-23 06:54:00	1	4.9000	45.0000
1856	2016-03-23 06:55:00	1	-4.2000	53.0000
1857	2016-03-23 06:56:00	1	22.7000	41.0000
1858	2016-03-23 06:57:00	1	4.5000	68.0000
1859	2016-03-23 06:58:00	1	17.1000	44.0000
1860	2016-03-23 06:59:00	1	9.2000	56.0000
1861	2016-03-23 07:00:00	1	-8.8000	68.0000
1862	2016-03-23 07:01:00	1	8.7000	57.0000
1863	2016-03-23 07:02:00	1	16.9000	43.0000
1864	2016-03-23 07:03:00	1	19.2000	53.0000
1865	2016-03-23 07:04:00	1	10.4000	55.0000
1866	2016-03-23 07:05:00	1	6.5000	52.0000
1867	2016-03-23 07:06:00	1	13.4000	74.0000
1868	2016-03-23 07:07:00	1	-7.4000	78.0000
1869	2016-03-23 07:08:00	1	23.9000	61.0000
1870	2016-03-23 07:09:00	1	20.0000	65.0000
1871	2016-03-23 07:10:00	1	11.9000	72.0000
1872	2016-03-23 07:11:00	1	5.6000	57.0000
1873	2016-03-23 07:12:00	1	-3.8000	63.0000
1874	2016-03-23 07:13:00	1	7.1000	51.0000
1875	2016-03-23 07:14:00	1	23.9000	56.0000
1876	2016-03-23 07:15:00	1	24.5000	72.0000
1877	2016-03-23 07:16:00	1	27.2000	41.0000
1878	2016-03-23 07:17:00	1	-7.2000	74.0000
1879	2016-03-23 07:18:00	1	-6.6000	67.0000
1880	2016-03-23 07:19:00	1	22.3000	62.0000
1881	2016-03-23 07:20:00	1	9.5000	41.0000
1882	2016-03-23 07:21:00	1	12.3000	48.0000
1883	2016-03-23 07:22:00	1	16.4000	66.0000
1884	2016-03-23 07:23:00	1	11.5000	78.0000
1885	2016-03-23 07:24:00	1	24.6000	73.0000
1886	2016-03-23 07:25:00	1	19.2000	54.0000
1887	2016-03-23 07:26:00	1	-2.7000	60.0000
1888	2016-03-23 07:27:00	1	21.1000	77.0000
1889	2016-03-23 07:28:00	1	24.9000	57.0000
1890	2016-03-23 07:29:00	1	-3.3000	51.0000
1891	2016-03-23 07:30:00	1	-5.4000	76.0000
1892	2016-03-23 07:31:00	1	13.9000	76.0000
1893	2016-03-23 07:32:00	1	4.4000	51.0000
1894	2016-03-23 07:33:00	1	15.8000	42.0000
1895	2016-03-23 07:34:00	1	8.7000	58.0000
1896	2016-03-23 07:35:00	1	-8.5000	40.0000
1897	2016-03-23 07:36:00	1	16.9000	78.0000
1898	2016-03-23 07:37:00	1	-9.0000	53.0000
1899	2016-03-23 07:38:00	1	-1.3000	74.0000
1900	2016-03-23 07:39:00	1	23.7000	52.0000
1901	2016-03-23 07:40:00	1	23.9000	54.0000
1902	2016-03-23 07:41:00	1	9.8000	52.0000
1903	2016-03-23 07:42:00	1	17.7000	77.0000
1904	2016-03-23 07:43:00	1	4.6000	58.0000
1905	2016-03-23 07:44:00	1	9.2000	58.0000
1906	2016-03-23 07:45:00	1	1.4000	66.0000
1907	2016-03-23 07:46:00	1	12.5000	52.0000
1908	2016-03-23 07:47:00	1	15.5000	72.0000
1909	2016-03-23 07:48:00	1	12.0000	53.0000
1910	2016-03-23 07:49:00	1	4.6000	60.0000
1911	2016-03-23 07:50:00	1	19.4000	78.0000
1912	2016-03-23 07:51:00	1	28.8000	50.0000
1913	2016-03-23 07:52:00	1	29.8000	48.0000
1914	2016-03-23 07:53:00	1	19.6000	61.0000
1915	2016-03-23 07:54:00	1	12.3000	74.0000
1916	2016-03-23 07:55:00	1	1.9000	70.0000
1917	2016-03-23 07:56:00	1	-3.9000	59.0000
1918	2016-03-23 07:57:00	1	7.4000	43.0000
1919	2016-03-23 07:58:00	1	-7.3000	71.0000
1920	2016-03-23 07:59:00	1	6.5000	70.0000
1921	2016-03-23 08:00:00	1	3.3000	71.0000
1922	2016-03-23 08:01:00	1	-4.4000	44.0000
1923	2016-03-23 08:02:00	1	13.2000	59.0000
1924	2016-03-23 08:03:00	1	22.6000	45.0000
1925	2016-03-23 08:04:00	1	-7.6000	69.0000
1926	2016-03-23 08:05:00	1	-4.1000	63.0000
1927	2016-03-23 08:06:00	1	13.3000	44.0000
1928	2016-03-23 08:07:00	1	-1.9000	62.0000
1929	2016-03-23 08:08:00	1	-5.5000	56.0000
1930	2016-03-23 08:09:00	1	21.7000	55.0000
1931	2016-03-23 08:10:00	1	10.9000	56.0000
1932	2016-03-23 08:11:00	1	-7.1000	59.0000
1933	2016-03-23 08:12:00	1	25.2000	46.0000
1934	2016-03-23 08:13:00	1	10.9000	72.0000
1935	2016-03-23 08:14:00	1	2.4000	44.0000
1936	2016-03-23 08:15:00	1	9.7000	67.0000
1937	2016-03-23 08:16:00	1	15.3000	79.0000
1938	2016-03-23 08:17:00	1	11.6000	57.0000
1939	2016-03-23 08:18:00	1	6.5000	65.0000
1940	2016-03-23 08:19:00	1	3.7000	50.0000
1941	2016-03-23 08:20:00	1	11.4000	46.0000
1942	2016-03-23 08:21:00	1	0.8000	60.0000
1943	2016-03-23 08:22:00	1	14.2000	66.0000
1944	2016-03-23 08:23:00	1	17.8000	43.0000
1945	2016-03-23 08:24:00	1	6.6000	66.0000
1946	2016-03-23 08:25:00	1	5.4000	72.0000
1947	2016-03-23 08:26:00	1	13.0000	42.0000
1948	2016-03-23 08:27:00	1	14.5000	58.0000
1949	2016-03-23 08:28:00	1	28.7000	53.0000
1950	2016-03-23 08:29:00	1	6.0000	65.0000
1951	2016-03-23 08:30:00	1	-7.2000	72.0000
1952	2016-03-23 08:31:00	1	26.8000	51.0000
1953	2016-03-23 08:32:00	1	11.1000	42.0000
1954	2016-03-23 08:33:00	1	26.5000	48.0000
1955	2016-03-23 08:34:00	1	22.6000	49.0000
1956	2016-03-23 08:35:00	1	6.5000	61.0000
1957	2016-03-23 08:36:00	1	19.8000	51.0000
1958	2016-03-23 08:37:00	1	8.7000	65.0000
1959	2016-03-23 08:38:00	1	-3.8000	65.0000
1960	2016-03-23 08:39:00	1	-7.4000	58.0000
1961	2016-03-23 08:40:00	1	15.9000	46.0000
1962	2016-03-23 08:41:00	1	10.2000	73.0000
1963	2016-03-23 08:42:00	1	26.4000	60.0000
1964	2016-03-23 08:43:00	1	17.0000	56.0000
1965	2016-03-23 08:44:00	1	0.2000	60.0000
1966	2016-03-23 08:45:00	1	-3.8000	69.0000
1967	2016-03-23 08:46:00	1	28.8000	52.0000
1968	2016-03-23 08:47:00	1	-8.9000	42.0000
1969	2016-03-23 08:48:00	1	11.4000	68.0000
1970	2016-03-23 08:49:00	1	7.5000	61.0000
1971	2016-03-23 08:50:00	1	-2.2000	67.0000
1972	2016-03-23 08:51:00	1	18.0000	52.0000
1973	2016-03-23 08:52:00	1	11.3000	65.0000
1974	2016-03-23 08:53:00	1	1.6000	55.0000
1975	2016-03-23 08:54:00	1	3.1000	45.0000
1976	2016-03-23 08:55:00	1	0.2000	60.0000
1977	2016-03-23 08:56:00	1	22.2000	43.0000
1978	2016-03-23 08:57:00	1	-2.1000	59.0000
1979	2016-03-23 08:58:00	1	25.2000	63.0000
1980	2016-03-23 08:59:00	1	13.7000	77.0000
1981	2016-03-23 09:00:00	1	28.0000	75.0000
1982	2016-03-23 09:01:00	1	8.4000	56.0000
1983	2016-03-23 09:02:00	1	22.9000	46.0000
1984	2016-03-23 09:03:00	1	6.6000	41.0000
1985	2016-03-23 09:04:00	1	7.1000	47.0000
1986	2016-03-23 09:05:00	1	18.4000	50.0000
1987	2016-03-23 09:06:00	1	18.2000	66.0000
1988	2016-03-23 09:07:00	1	12.5000	53.0000
1989	2016-03-23 09:08:00	1	13.0000	79.0000
1990	2016-03-23 09:09:00	1	27.0000	60.0000
1991	2016-03-23 09:10:00	1	-1.7000	61.0000
1992	2016-03-23 09:11:00	1	25.2000	76.0000
1993	2016-03-23 09:12:00	1	27.7000	72.0000
1994	2016-03-23 09:13:00	1	19.2000	67.0000
1995	2016-03-23 09:14:00	1	28.0000	49.0000
1996	2016-03-23 09:15:00	1	28.3000	40.0000
1997	2016-03-23 09:16:00	1	-7.2000	70.0000
1998	2016-03-23 09:17:00	1	22.7000	72.0000
1999	2016-03-23 09:18:00	1	26.2000	53.0000
2000	2016-03-23 09:19:00	1	0.0000	69.0000
2001	2016-03-23 09:20:00	1	-6.5000	56.0000
2002	2016-03-23 09:21:00	1	28.3000	75.0000
2003	2016-03-23 09:22:00	1	4.7000	42.0000
2004	2016-03-23 09:23:00	1	-8.8000	52.0000
2005	2016-03-23 09:24:00	1	5.0000	56.0000
2006	2016-03-23 09:25:00	1	23.9000	46.0000
2007	2016-03-23 09:26:00	1	-4.6000	71.0000
2008	2016-03-23 09:27:00	1	13.8000	40.0000
2009	2016-03-23 09:28:00	1	22.2000	57.0000
2010	2016-03-23 09:29:00	1	26.0000	59.0000
2011	2016-03-23 09:30:00	1	15.9000	71.0000
2012	2016-03-23 09:31:00	1	16.2000	51.0000
2013	2016-03-23 09:32:00	1	1.1000	54.0000
2014	2016-03-23 09:33:00	1	14.4000	57.0000
2015	2016-03-23 09:34:00	1	18.2000	55.0000
2016	2016-03-23 09:35:00	1	10.7000	67.0000
2017	2016-03-23 09:36:00	1	22.8000	66.0000
2018	2016-03-23 09:37:00	1	13.3000	73.0000
2019	2016-03-23 09:38:00	1	29.9000	50.0000
2020	2016-03-23 09:39:00	1	-4.7000	69.0000
2021	2016-03-23 09:40:00	1	12.7000	76.0000
2022	2016-03-23 09:41:00	1	28.1000	63.0000
2023	2016-03-23 09:42:00	1	18.4000	78.0000
2024	2016-03-23 09:43:00	1	21.3000	50.0000
2025	2016-03-23 09:44:00	1	24.9000	51.0000
2026	2016-03-23 09:45:00	1	0.9000	42.0000
2027	2016-03-23 09:46:00	1	11.6000	48.0000
2028	2016-03-23 09:47:00	1	-0.5000	63.0000
2029	2016-03-23 09:48:00	1	5.9000	55.0000
2030	2016-03-23 09:49:00	1	-10.0000	68.0000
2031	2016-03-23 09:50:00	1	18.3000	46.0000
2032	2016-03-23 09:51:00	1	25.8000	42.0000
2033	2016-03-23 09:52:00	1	29.7000	58.0000
2034	2016-03-23 09:53:00	1	18.7000	60.0000
2035	2016-03-23 09:54:00	1	-6.4000	59.0000
2036	2016-03-23 09:55:00	1	4.3000	55.0000
2037	2016-03-23 09:56:00	1	23.3000	45.0000
2038	2016-03-23 09:57:00	1	4.4000	42.0000
2039	2016-03-23 09:58:00	1	24.4000	61.0000
2040	2016-03-23 09:59:00	1	-7.7000	79.0000
2041	2016-03-23 10:00:00	1	23.0000	41.0000
2042	2016-03-23 10:01:00	1	0.1000	53.0000
2043	2016-03-23 10:02:00	1	0.3000	74.0000
2044	2016-03-23 10:03:00	1	-2.7000	51.0000
2045	2016-03-23 10:04:00	1	3.5000	57.0000
2046	2016-03-23 10:05:00	1	20.3000	60.0000
2047	2016-03-23 10:06:00	1	18.0000	55.0000
2048	2016-03-23 10:07:00	1	12.9000	55.0000
2049	2016-03-23 10:08:00	1	-4.8000	57.0000
2050	2016-03-23 10:09:00	1	17.2000	41.0000
2051	2016-03-23 10:10:00	1	-4.4000	64.0000
2052	2016-03-23 10:11:00	1	25.0000	52.0000
2053	2016-03-23 10:12:00	1	4.0000	73.0000
2054	2016-03-23 10:13:00	1	10.6000	53.0000
2055	2016-03-23 10:14:00	1	5.1000	66.0000
2056	2016-03-23 10:15:00	1	27.6000	65.0000
2057	2016-03-23 10:16:00	1	26.2000	53.0000
2058	2016-03-23 10:17:00	1	12.8000	57.0000
2059	2016-03-23 10:18:00	1	17.3000	75.0000
2060	2016-03-23 10:19:00	1	22.7000	56.0000
2061	2016-03-23 10:20:00	1	27.4000	46.0000
2062	2016-03-23 10:21:00	1	-7.4000	75.0000
2063	2016-03-23 10:22:00	1	-0.9000	59.0000
2064	2016-03-23 10:23:00	1	3.1000	53.0000
2065	2016-03-23 10:24:00	1	27.2000	44.0000
2066	2016-03-23 10:25:00	1	13.0000	52.0000
2067	2016-03-23 10:26:00	1	-8.2000	50.0000
2068	2016-03-23 10:27:00	1	-8.2000	78.0000
2069	2016-03-23 10:28:00	1	17.5000	78.0000
2070	2016-03-23 10:29:00	1	14.1000	56.0000
2071	2016-03-23 10:30:00	1	-4.6000	42.0000
2072	2016-03-23 10:31:00	1	0.7000	52.0000
2073	2016-03-23 10:32:00	1	19.4000	79.0000
2074	2016-03-23 10:33:00	1	-1.8000	62.0000
2075	2016-03-23 10:34:00	1	13.6000	76.0000
2076	2016-03-23 10:35:00	1	7.5000	46.0000
2077	2016-03-23 10:36:00	1	13.8000	54.0000
2078	2016-03-23 10:37:00	1	-3.6000	43.0000
2079	2016-03-23 10:38:00	1	-4.3000	50.0000
2080	2016-03-23 10:39:00	1	-2.9000	48.0000
2081	2016-03-23 10:40:00	1	9.7000	51.0000
2082	2016-03-23 10:41:00	1	-4.2000	62.0000
2083	2016-03-23 10:42:00	1	-1.9000	45.0000
2084	2016-03-23 10:43:00	1	27.3000	44.0000
2085	2016-03-23 10:44:00	1	20.1000	50.0000
2086	2016-03-23 10:45:00	1	28.2000	68.0000
2087	2016-03-23 10:46:00	1	-7.0000	61.0000
2088	2016-03-23 10:47:00	1	27.2000	47.0000
2089	2016-03-23 10:48:00	1	-7.5000	69.0000
2090	2016-03-23 10:49:00	1	-0.9000	55.0000
2091	2016-03-23 10:50:00	1	-3.8000	47.0000
2092	2016-03-23 10:51:00	1	-3.0000	47.0000
2093	2016-03-23 10:52:00	1	-3.3000	41.0000
2094	2016-03-23 10:53:00	1	12.9000	53.0000
2095	2016-03-23 10:54:00	1	22.9000	67.0000
2096	2016-03-23 10:55:00	1	5.3000	45.0000
2097	2016-03-23 10:56:00	1	10.2000	62.0000
2098	2016-03-23 10:57:00	1	24.2000	79.0000
2099	2016-03-23 10:58:00	1	18.7000	47.0000
2100	2016-03-23 10:59:00	1	13.9000	70.0000
2101	2016-03-23 11:00:00	1	2.8000	42.0000
2102	2016-03-23 11:01:00	1	4.3000	50.0000
2103	2016-03-23 11:02:00	1	21.1000	57.0000
2104	2016-03-23 11:03:00	1	-1.8000	43.0000
2105	2016-03-23 11:04:00	1	6.8000	66.0000
2106	2016-03-23 11:05:00	1	9.7000	50.0000
2107	2016-03-23 11:06:00	1	-6.2000	59.0000
2108	2016-03-23 11:07:00	1	2.9000	53.0000
2109	2016-03-23 11:08:00	1	-9.9000	48.0000
2110	2016-03-23 11:09:00	1	12.9000	51.0000
2111	2016-03-23 11:10:00	1	15.9000	48.0000
2112	2016-03-23 11:11:00	1	-4.4000	73.0000
2113	2016-03-23 11:12:00	1	9.3000	64.0000
2114	2016-03-23 11:13:00	1	24.3000	77.0000
2115	2016-03-23 11:14:00	1	21.2000	54.0000
2116	2016-03-23 11:15:00	1	16.8000	68.0000
2117	2016-03-23 11:16:00	1	-9.6000	44.0000
2118	2016-03-23 11:17:00	1	9.9000	79.0000
2119	2016-03-23 11:18:00	1	2.5000	55.0000
2120	2016-03-23 11:19:00	1	15.2000	67.0000
2121	2016-03-23 11:20:00	1	-4.6000	40.0000
2122	2016-03-23 11:21:00	1	2.2000	53.0000
2123	2016-03-23 11:22:00	1	21.5000	55.0000
2124	2016-03-23 11:23:00	1	9.8000	59.0000
2125	2016-03-23 11:24:00	1	11.0000	52.0000
2126	2016-03-23 11:25:00	1	14.6000	77.0000
2127	2016-03-23 11:26:00	1	-9.2000	67.0000
2128	2016-03-23 11:27:00	1	2.8000	70.0000
2129	2016-03-23 11:28:00	1	20.0000	41.0000
2130	2016-03-23 11:29:00	1	18.1000	62.0000
2131	2016-03-23 11:30:00	1	15.4000	53.0000
2132	2016-03-23 11:31:00	1	15.3000	71.0000
2133	2016-03-23 11:32:00	1	5.9000	49.0000
2134	2016-03-23 11:33:00	1	7.4000	79.0000
2135	2016-03-23 11:34:00	1	23.3000	52.0000
2136	2016-03-23 11:35:00	1	7.7000	44.0000
2137	2016-03-23 11:36:00	1	-2.6000	63.0000
2138	2016-03-23 11:37:00	1	-2.0000	52.0000
2139	2016-03-23 11:38:00	1	5.0000	43.0000
2140	2016-03-23 11:39:00	1	20.6000	40.0000
2141	2016-03-23 11:40:00	1	20.5000	42.0000
2142	2016-03-23 11:41:00	1	-7.2000	75.0000
2143	2016-03-23 11:42:00	1	-4.5000	46.0000
2144	2016-03-23 11:43:00	1	1.4000	60.0000
2145	2016-03-23 11:44:00	1	12.8000	52.0000
2146	2016-03-23 11:45:00	1	6.7000	61.0000
2147	2016-03-23 11:46:00	1	4.4000	52.0000
2148	2016-03-23 11:47:00	1	24.0000	63.0000
2149	2016-03-23 11:48:00	1	-2.8000	61.0000
2150	2016-03-23 11:49:00	1	8.8000	64.0000
2151	2016-03-23 11:50:00	1	4.0000	48.0000
2152	2016-03-23 11:51:00	1	29.3000	46.0000
2153	2016-03-23 11:52:00	1	16.3000	45.0000
2154	2016-03-23 11:53:00	1	10.5000	68.0000
2155	2016-03-23 11:54:00	1	25.2000	69.0000
2156	2016-03-23 11:55:00	1	27.3000	43.0000
2157	2016-03-23 11:56:00	1	16.4000	64.0000
2158	2016-03-23 11:57:00	1	6.9000	79.0000
2159	2016-03-23 11:58:00	1	5.7000	63.0000
2160	2016-03-23 11:59:00	1	17.3000	76.0000
2161	2016-03-23 12:00:00	1	17.8000	60.0000
2162	2016-03-23 12:01:00	1	-3.4000	40.0000
2163	2016-03-23 12:02:00	1	-3.9000	48.0000
2164	2016-03-23 12:03:00	1	22.6000	73.0000
2165	2016-03-23 12:04:00	1	2.1000	45.0000
2166	2016-03-23 12:05:00	1	3.8000	43.0000
2167	2016-03-23 12:06:00	1	-2.2000	45.0000
2168	2016-03-23 12:07:00	1	-2.4000	63.0000
2169	2016-03-23 12:08:00	1	10.5000	47.0000
2170	2016-03-23 12:09:00	1	25.4000	58.0000
2171	2016-03-23 12:10:00	1	29.2000	79.0000
2172	2016-03-23 12:11:00	1	-8.6000	47.0000
2173	2016-03-23 12:12:00	1	22.7000	58.0000
2174	2016-03-23 12:13:00	1	7.4000	53.0000
2175	2016-03-23 12:14:00	1	-3.4000	44.0000
2176	2016-03-23 12:15:00	1	-3.2000	55.0000
2177	2016-03-23 12:16:00	1	-1.2000	65.0000
2178	2016-03-23 12:17:00	1	26.7000	77.0000
2179	2016-03-23 12:18:00	1	4.0000	59.0000
2180	2016-03-23 12:19:00	1	18.1000	43.0000
2181	2016-03-23 12:20:00	1	-9.4000	48.0000
2182	2016-03-23 12:21:00	1	2.2000	77.0000
2183	2016-03-23 12:22:00	1	5.2000	54.0000
2184	2016-03-23 12:23:00	1	-7.6000	44.0000
2185	2016-03-23 12:24:00	1	-2.2000	52.0000
2186	2016-03-23 12:25:00	1	1.4000	77.0000
2187	2016-03-23 12:26:00	1	20.5000	61.0000
2188	2016-03-23 12:27:00	1	22.5000	74.0000
2189	2016-03-23 12:28:00	1	21.1000	49.0000
2190	2016-03-23 12:29:00	1	21.5000	40.0000
2191	2016-03-23 12:30:00	1	4.5000	56.0000
2192	2016-03-23 12:31:00	1	22.1000	58.0000
2193	2016-03-23 12:32:00	1	1.6000	51.0000
2194	2016-03-23 12:33:00	1	28.1000	55.0000
2195	2016-03-23 12:34:00	1	8.1000	67.0000
2196	2016-03-23 12:35:00	1	1.7000	74.0000
2197	2016-03-23 12:36:00	1	18.3000	42.0000
2198	2016-03-23 12:37:00	1	17.1000	48.0000
2199	2016-03-23 12:38:00	1	-6.3000	51.0000
2200	2016-03-23 12:39:00	1	29.1000	57.0000
2201	2016-03-23 12:40:00	1	17.3000	53.0000
2202	2016-03-23 12:41:00	1	8.5000	74.0000
2203	2016-03-23 12:42:00	1	13.4000	57.0000
2204	2016-03-23 12:43:00	1	-9.1000	73.0000
2205	2016-03-23 12:44:00	1	10.8000	55.0000
2206	2016-03-23 12:45:00	1	2.1000	60.0000
2207	2016-03-23 12:46:00	1	20.7000	48.0000
2208	2016-03-23 12:47:00	1	8.7000	52.0000
2209	2016-03-23 12:48:00	1	23.1000	74.0000
2210	2016-03-23 12:49:00	1	18.0000	49.0000
2211	2016-03-23 12:50:00	1	-6.9000	64.0000
2212	2016-03-23 12:51:00	1	19.9000	55.0000
2213	2016-03-23 12:52:00	1	13.6000	74.0000
2214	2016-03-23 12:53:00	1	24.8000	63.0000
2215	2016-03-23 12:54:00	1	-3.6000	55.0000
2216	2016-03-23 12:55:00	1	28.8000	67.0000
2217	2016-03-23 12:56:00	1	-5.5000	54.0000
2218	2016-03-23 12:57:00	1	1.4000	43.0000
2219	2016-03-23 12:58:00	1	18.3000	49.0000
2220	2016-03-23 12:59:00	1	-7.7000	57.0000
2221	2016-03-23 13:00:00	1	-5.3000	69.0000
2222	2016-03-23 13:01:00	1	-5.5000	56.0000
2223	2016-03-23 13:02:00	1	8.7000	54.0000
2224	2016-03-23 13:03:00	1	27.7000	57.0000
2225	2016-03-23 13:04:00	1	-10.0000	75.0000
2226	2016-03-23 13:05:00	1	13.0000	68.0000
2227	2016-03-23 13:06:00	1	15.4000	49.0000
2228	2016-03-23 13:07:00	1	24.4000	45.0000
2229	2016-03-23 13:08:00	1	19.7000	47.0000
2230	2016-03-23 13:09:00	1	26.3000	68.0000
2231	2016-03-23 13:10:00	1	13.1000	68.0000
2232	2016-03-23 13:11:00	1	19.8000	51.0000
2233	2016-03-23 13:12:00	1	2.3000	56.0000
2234	2016-03-23 13:13:00	1	5.4000	52.0000
2235	2016-03-23 13:14:00	1	3.5000	50.0000
2236	2016-03-23 13:15:00	1	-0.3000	50.0000
2237	2016-03-23 13:16:00	1	22.1000	45.0000
2238	2016-03-23 13:17:00	1	3.7000	57.0000
2239	2016-03-23 13:18:00	1	27.4000	53.0000
2240	2016-03-23 13:19:00	1	12.6000	68.0000
2241	2016-03-23 13:20:00	1	27.1000	61.0000
2242	2016-03-23 13:21:00	1	-9.6000	46.0000
2243	2016-03-23 13:22:00	1	8.4000	59.0000
2244	2016-03-23 13:23:00	1	21.4000	53.0000
2245	2016-03-23 13:24:00	1	13.9000	79.0000
2246	2016-03-23 13:25:00	1	-5.8000	49.0000
2247	2016-03-23 13:26:00	1	12.7000	55.0000
2248	2016-03-23 13:27:00	1	24.5000	68.0000
2249	2016-03-23 13:28:00	1	25.3000	53.0000
2250	2016-03-23 13:29:00	1	25.7000	57.0000
2251	2016-03-23 13:30:00	1	17.5000	49.0000
2252	2016-03-23 13:31:00	1	17.1000	62.0000
2253	2016-03-23 13:32:00	1	9.6000	52.0000
2254	2016-03-23 13:33:00	1	20.5000	54.0000
2255	2016-03-23 13:34:00	1	2.1000	73.0000
2256	2016-03-23 13:35:00	1	4.3000	73.0000
2257	2016-03-23 13:36:00	1	8.6000	57.0000
2258	2016-03-23 13:37:00	1	21.6000	64.0000
2259	2016-03-23 13:38:00	1	-0.5000	70.0000
2260	2016-03-23 13:39:00	1	-4.9000	43.0000
2261	2016-03-23 13:40:00	1	0.7000	77.0000
2262	2016-03-23 13:41:00	1	-9.6000	55.0000
2263	2016-03-23 13:42:00	1	-6.6000	51.0000
2264	2016-03-23 13:43:00	1	18.5000	64.0000
2265	2016-03-23 13:44:00	1	-5.2000	42.0000
2266	2016-03-23 13:45:00	1	-2.5000	47.0000
2267	2016-03-23 13:46:00	1	19.6000	47.0000
2268	2016-03-23 13:47:00	1	2.0000	45.0000
2269	2016-03-23 13:48:00	1	25.3000	48.0000
2270	2016-03-23 13:49:00	1	16.1000	45.0000
2271	2016-03-23 13:50:00	1	5.5000	60.0000
2272	2016-03-23 13:51:00	1	6.5000	55.0000
2273	2016-03-23 13:52:00	1	5.1000	77.0000
2274	2016-03-23 13:53:00	1	21.1000	54.0000
2275	2016-03-23 13:54:00	1	21.1000	76.0000
2276	2016-03-23 13:55:00	1	8.0000	76.0000
2277	2016-03-23 13:56:00	1	-4.5000	50.0000
2278	2016-03-23 13:57:00	1	25.3000	65.0000
2279	2016-03-23 13:58:00	1	3.2000	74.0000
2280	2016-03-23 13:59:00	1	-2.5000	46.0000
2281	2016-03-23 14:00:00	1	-2.0000	69.0000
2282	2016-03-23 14:01:00	1	0.3000	48.0000
2283	2016-03-23 14:02:00	1	-0.5000	62.0000
2284	2016-03-23 14:03:00	1	-3.2000	76.0000
2285	2016-03-23 14:04:00	1	14.7000	71.0000
2286	2016-03-23 14:05:00	1	2.1000	72.0000
2287	2016-03-23 14:06:00	1	23.4000	59.0000
2288	2016-03-23 14:07:00	1	24.2000	49.0000
2289	2016-03-23 14:08:00	1	26.7000	47.0000
2290	2016-03-23 14:09:00	1	23.1000	63.0000
2291	2016-03-23 14:10:00	1	11.5000	41.0000
2292	2016-03-23 14:11:00	1	19.6000	55.0000
2293	2016-03-23 14:12:00	1	19.4000	50.0000
2294	2016-03-23 14:13:00	1	25.9000	72.0000
2295	2016-03-23 14:14:00	1	-1.4000	68.0000
2296	2016-03-23 14:15:00	1	10.5000	42.0000
2297	2016-03-23 14:16:00	1	8.4000	71.0000
2298	2016-03-23 14:17:00	1	4.3000	55.0000
2299	2016-03-23 14:18:00	1	3.0000	62.0000
2300	2016-03-23 14:19:00	1	22.6000	64.0000
2301	2016-03-23 14:20:00	1	4.1000	52.0000
2302	2016-03-23 14:21:00	1	27.8000	65.0000
2303	2016-03-23 14:22:00	1	23.3000	63.0000
2304	2016-03-23 14:23:00	1	6.0000	67.0000
2305	2016-03-23 14:24:00	1	7.4000	57.0000
2306	2016-03-23 14:25:00	1	7.7000	52.0000
2307	2016-03-23 14:26:00	1	10.1000	49.0000
2308	2016-03-23 14:27:00	1	15.9000	69.0000
2309	2016-03-23 14:28:00	1	22.1000	66.0000
2310	2016-03-23 14:29:00	1	2.0000	44.0000
2311	2016-03-23 14:30:00	1	15.2000	59.0000
2312	2016-03-23 14:31:00	1	7.4000	72.0000
2313	2016-03-23 14:32:00	1	13.3000	75.0000
2314	2016-03-23 14:33:00	1	21.5000	44.0000
2315	2016-03-23 14:34:00	1	2.8000	58.0000
2316	2016-03-23 14:35:00	1	24.0000	51.0000
2317	2016-03-23 14:36:00	1	18.8000	43.0000
2318	2016-03-23 14:37:00	1	24.3000	42.0000
2319	2016-03-23 14:38:00	1	13.9000	49.0000
2320	2016-03-23 14:39:00	1	2.0000	76.0000
2321	2016-03-23 14:40:00	1	9.4000	59.0000
2322	2016-03-23 14:41:00	1	-9.8000	64.0000
2323	2016-03-23 14:42:00	1	27.0000	55.0000
2324	2016-03-23 14:43:00	1	-1.1000	67.0000
2325	2016-03-23 14:44:00	1	-2.1000	74.0000
2326	2016-03-23 14:45:00	1	19.7000	75.0000
2327	2016-03-23 14:46:00	1	3.5000	77.0000
2328	2016-03-23 14:47:00	1	26.7000	44.0000
2329	2016-03-23 14:48:00	1	28.7000	55.0000
2330	2016-03-23 14:49:00	1	23.1000	69.0000
2331	2016-03-23 14:50:00	1	2.3000	55.0000
2332	2016-03-23 14:51:00	1	28.3000	44.0000
2333	2016-03-23 14:52:00	1	8.8000	55.0000
2334	2016-03-23 14:53:00	1	13.1000	44.0000
2335	2016-03-23 14:54:00	1	-7.0000	76.0000
2336	2016-03-23 14:55:00	1	-6.1000	50.0000
2337	2016-03-23 14:56:00	1	14.9000	68.0000
2338	2016-03-23 14:57:00	1	11.8000	42.0000
2339	2016-03-23 14:58:00	1	20.2000	47.0000
2340	2016-03-23 14:59:00	1	0.8000	44.0000
2341	2016-03-23 15:00:00	1	1.7000	40.0000
2342	2016-03-23 15:01:00	1	21.3000	75.0000
2343	2016-03-23 15:02:00	1	-2.4000	47.0000
2344	2016-03-23 15:03:00	1	11.9000	69.0000
2345	2016-03-23 15:04:00	1	6.2000	66.0000
2346	2016-03-23 15:05:00	1	7.9000	55.0000
2347	2016-03-23 15:06:00	1	-7.9000	58.0000
2348	2016-03-23 15:07:00	1	19.6000	58.0000
2349	2016-03-23 15:08:00	1	-1.1000	65.0000
2350	2016-03-23 15:09:00	1	13.6000	57.0000
2351	2016-03-23 15:10:00	1	-2.2000	43.0000
2352	2016-03-23 15:11:00	1	24.2000	75.0000
2353	2016-03-23 15:12:00	1	21.7000	42.0000
2354	2016-03-23 15:13:00	1	4.5000	54.0000
2355	2016-03-23 15:14:00	1	-3.2000	67.0000
2356	2016-03-23 15:15:00	1	10.0000	70.0000
2357	2016-03-23 15:16:00	1	15.9000	57.0000
2358	2016-03-23 15:17:00	1	-6.3000	43.0000
2359	2016-03-23 15:18:00	1	29.3000	63.0000
2360	2016-03-23 15:19:00	1	29.9000	46.0000
2361	2016-03-23 15:20:00	1	-9.4000	50.0000
2362	2016-03-23 15:21:00	1	-6.1000	68.0000
2363	2016-03-23 15:22:00	1	24.1000	79.0000
2364	2016-03-23 15:23:00	1	13.6000	40.0000
2365	2016-03-23 15:24:00	1	-3.8000	49.0000
2366	2016-03-23 15:25:00	1	4.9000	65.0000
2367	2016-03-23 15:26:00	1	24.8000	65.0000
2368	2016-03-23 15:27:00	1	-3.3000	63.0000
2369	2016-03-23 15:28:00	1	15.1000	58.0000
2370	2016-03-23 15:29:00	1	-1.7000	55.0000
2371	2016-03-23 15:30:00	1	-3.4000	75.0000
2372	2016-03-23 15:31:00	1	0.4000	51.0000
2373	2016-03-23 15:32:00	1	29.6000	49.0000
2374	2016-03-23 15:33:00	1	16.0000	56.0000
2375	2016-03-23 15:34:00	1	29.7000	47.0000
2376	2016-03-23 15:35:00	1	4.3000	40.0000
2377	2016-03-23 15:36:00	1	-6.2000	62.0000
2378	2016-03-23 15:37:00	1	-7.0000	44.0000
2379	2016-03-23 15:38:00	1	1.7000	75.0000
2380	2016-03-23 15:39:00	1	-9.1000	66.0000
2381	2016-03-23 15:40:00	1	23.8000	42.0000
2382	2016-03-23 15:41:00	1	21.9000	75.0000
2383	2016-03-23 15:42:00	1	14.8000	52.0000
2384	2016-03-23 15:43:00	1	5.0000	53.0000
2385	2016-03-23 15:44:00	1	9.9000	54.0000
2386	2016-03-23 15:45:00	1	-8.2000	55.0000
2387	2016-03-23 15:46:00	1	1.6000	53.0000
2388	2016-03-23 15:47:00	1	9.0000	41.0000
2389	2016-03-23 15:48:00	1	16.3000	61.0000
2390	2016-03-23 15:49:00	1	-0.1000	55.0000
2391	2016-03-23 15:50:00	1	21.1000	78.0000
2392	2016-03-23 15:51:00	1	16.3000	43.0000
2393	2016-03-23 15:52:00	1	-7.6000	63.0000
2394	2016-03-23 15:53:00	1	22.8000	61.0000
2395	2016-03-23 15:54:00	1	5.9000	51.0000
2396	2016-03-23 15:55:00	1	22.0000	41.0000
2397	2016-03-23 15:56:00	1	-0.6000	78.0000
2398	2016-03-23 15:57:00	1	28.2000	79.0000
2399	2016-03-23 15:58:00	1	12.6000	53.0000
2400	2016-03-23 15:59:00	1	-5.9000	40.0000
2401	2016-03-23 16:00:00	1	26.4000	41.0000
2402	2016-03-23 16:01:00	1	19.1000	57.0000
2403	2016-03-23 16:02:00	1	8.2000	41.0000
2404	2016-03-23 16:03:00	1	9.1000	76.0000
2405	2016-03-23 16:04:00	1	3.2000	55.0000
2406	2016-03-23 16:05:00	1	20.5000	68.0000
2407	2016-03-23 16:06:00	1	3.3000	66.0000
2408	2016-03-23 16:07:00	1	29.1000	74.0000
2409	2016-03-23 16:08:00	1	-3.9000	79.0000
2410	2016-03-23 16:09:00	1	19.8000	66.0000
2411	2016-03-23 16:10:00	1	15.5000	42.0000
2412	2016-03-23 16:11:00	1	21.6000	43.0000
2413	2016-03-23 16:12:00	1	-4.3000	63.0000
2414	2016-03-23 16:13:00	1	19.1000	71.0000
2415	2016-03-23 16:14:00	1	-7.1000	75.0000
2416	2016-03-23 16:15:00	1	20.9000	64.0000
2417	2016-03-23 16:16:00	1	29.2000	46.0000
2418	2016-03-23 16:17:00	1	-2.6000	70.0000
2419	2016-03-23 16:18:00	1	18.1000	79.0000
2420	2016-03-23 16:19:00	1	11.9000	48.0000
2421	2016-03-23 16:20:00	1	5.6000	57.0000
2422	2016-03-23 16:21:00	1	-4.5000	67.0000
2423	2016-03-23 16:22:00	1	19.3000	48.0000
2424	2016-03-23 16:23:00	1	-5.5000	52.0000
2425	2016-03-23 16:24:00	1	26.4000	55.0000
2426	2016-03-23 16:25:00	1	7.4000	78.0000
2427	2016-03-23 16:26:00	1	6.1000	45.0000
2428	2016-03-23 16:27:00	1	6.9000	58.0000
2429	2016-03-23 16:28:00	1	28.9000	65.0000
2430	2016-03-23 16:29:00	1	0.2000	64.0000
2431	2016-03-23 16:30:00	1	29.2000	40.0000
2432	2016-03-23 16:31:00	1	-8.8000	56.0000
2433	2016-03-23 16:32:00	1	11.1000	49.0000
2434	2016-03-23 16:33:00	1	5.8000	73.0000
2435	2016-03-23 16:34:00	1	25.0000	72.0000
2436	2016-03-23 16:35:00	1	0.4000	61.0000
2437	2016-03-23 16:36:00	1	0.1000	78.0000
2438	2016-03-23 16:37:00	1	29.5000	72.0000
2439	2016-03-23 16:38:00	1	10.4000	48.0000
2440	2016-03-23 16:39:00	1	24.8000	54.0000
2441	2016-03-23 16:40:00	1	28.3000	41.0000
2442	2016-03-23 16:41:00	1	28.8000	41.0000
2443	2016-03-23 16:42:00	1	11.3000	74.0000
2444	2016-03-23 16:43:00	1	26.4000	74.0000
2445	2016-03-23 16:44:00	1	11.6000	69.0000
2446	2016-03-23 16:45:00	1	12.0000	78.0000
2447	2016-03-23 16:46:00	1	-2.3000	66.0000
2448	2016-03-23 16:47:00	1	9.2000	55.0000
2449	2016-03-23 16:48:00	1	21.7000	40.0000
2450	2016-03-23 16:49:00	1	28.0000	43.0000
2451	2016-03-23 16:50:00	1	22.7000	69.0000
2452	2016-03-23 16:51:00	1	27.4000	60.0000
2453	2016-03-23 16:52:00	1	14.4000	52.0000
2454	2016-03-23 16:53:00	1	-7.8000	72.0000
2455	2016-03-23 16:54:00	1	-9.2000	56.0000
2456	2016-03-23 16:55:00	1	11.6000	44.0000
2457	2016-03-23 16:56:00	1	-0.7000	58.0000
2458	2016-03-23 16:57:00	1	3.7000	43.0000
2459	2016-03-23 16:58:00	1	26.0000	45.0000
2460	2016-03-23 16:59:00	1	0.8000	70.0000
2461	2016-03-23 17:00:00	1	6.6000	75.0000
2462	2016-03-23 17:01:00	1	28.4000	42.0000
2463	2016-03-23 17:02:00	1	6.1000	62.0000
2464	2016-03-23 17:03:00	1	3.2000	77.0000
2465	2016-03-23 17:04:00	1	2.6000	65.0000
2466	2016-03-23 17:05:00	1	24.6000	73.0000
2467	2016-03-23 17:06:00	1	9.7000	43.0000
2468	2016-03-23 17:07:00	1	-1.9000	60.0000
2469	2016-03-23 17:08:00	1	18.8000	45.0000
2470	2016-03-23 17:09:00	1	-1.2000	55.0000
2471	2016-03-23 17:10:00	1	-2.6000	79.0000
2472	2016-03-23 17:11:00	1	18.8000	78.0000
2473	2016-03-23 17:12:00	1	0.8000	44.0000
2474	2016-03-23 17:13:00	1	-2.7000	69.0000
2475	2016-03-23 17:14:00	1	2.5000	58.0000
2476	2016-03-23 17:15:00	1	14.3000	43.0000
2477	2016-03-23 17:16:00	1	1.0000	66.0000
2478	2016-03-23 17:17:00	1	3.5000	55.0000
2479	2016-03-23 17:18:00	1	-9.7000	43.0000
2480	2016-03-23 17:19:00	1	24.8000	49.0000
2481	2016-03-23 17:20:00	1	27.8000	51.0000
2482	2016-03-23 17:21:00	1	8.2000	42.0000
2483	2016-03-23 17:22:00	1	11.3000	75.0000
2484	2016-03-23 17:23:00	1	11.5000	49.0000
2485	2016-03-23 17:24:00	1	26.7000	75.0000
2486	2016-03-23 17:25:00	1	29.7000	40.0000
2487	2016-03-23 17:26:00	1	10.7000	43.0000
2488	2016-03-23 17:27:00	1	10.7000	51.0000
2489	2016-03-23 17:28:00	1	21.0000	59.0000
2490	2016-03-23 17:29:00	1	28.2000	56.0000
2491	2016-03-23 17:30:00	1	-3.9000	78.0000
2492	2016-03-23 17:31:00	1	22.7000	70.0000
2493	2016-03-23 17:32:00	1	-4.8000	45.0000
2494	2016-03-23 17:33:00	1	-6.0000	73.0000
2495	2016-03-23 17:34:00	1	22.8000	76.0000
2496	2016-03-23 17:35:00	1	8.4000	75.0000
2497	2016-03-23 17:36:00	1	18.3000	64.0000
2498	2016-03-23 17:37:00	1	-1.9000	41.0000
2499	2016-03-23 17:38:00	1	12.9000	59.0000
2500	2016-03-23 17:39:00	1	9.7000	78.0000
2501	2016-03-23 17:40:00	1	9.8000	74.0000
2502	2016-03-23 17:41:00	1	13.6000	68.0000
2503	2016-03-23 17:42:00	1	-2.0000	56.0000
2504	2016-03-23 17:43:00	1	22.0000	64.0000
2505	2016-03-23 17:44:00	1	22.2000	59.0000
2506	2016-03-23 17:45:00	1	-7.4000	52.0000
2507	2016-03-23 17:46:00	1	2.8000	60.0000
2508	2016-03-23 17:47:00	1	5.3000	42.0000
2509	2016-03-23 17:48:00	1	-8.5000	66.0000
2510	2016-03-23 17:49:00	1	13.6000	71.0000
2511	2016-03-23 17:50:00	1	8.2000	56.0000
2512	2016-03-23 17:51:00	1	14.9000	69.0000
2513	2016-03-23 17:52:00	1	28.6000	63.0000
2514	2016-03-23 17:53:00	1	6.1000	58.0000
2515	2016-03-23 17:54:00	1	12.5000	40.0000
2516	2016-03-23 17:55:00	1	-9.0000	76.0000
2517	2016-03-23 17:56:00	1	5.3000	74.0000
2518	2016-03-23 17:57:00	1	-7.1000	70.0000
2519	2016-03-23 17:58:00	1	18.8000	63.0000
2520	2016-03-23 17:59:00	1	12.3000	66.0000
2521	2016-03-23 18:00:00	1	15.2000	54.0000
2522	2016-03-23 18:01:00	1	9.2000	60.0000
2523	2016-03-23 18:02:00	1	10.2000	59.0000
2524	2016-03-23 18:03:00	1	6.1000	78.0000
2525	2016-03-23 18:04:00	1	3.8000	56.0000
2526	2016-03-23 18:05:00	1	5.9000	67.0000
2527	2016-03-23 18:06:00	1	-8.4000	56.0000
2528	2016-03-23 18:07:00	1	28.5000	72.0000
2529	2016-03-23 18:08:00	1	23.7000	45.0000
2530	2016-03-23 18:09:00	1	11.6000	62.0000
2531	2016-03-23 18:10:00	1	0.3000	66.0000
2532	2016-03-23 18:11:00	1	8.5000	79.0000
2533	2016-03-23 18:12:00	1	-2.8000	42.0000
2534	2016-03-23 18:13:00	1	-1.2000	72.0000
2535	2016-03-23 18:14:00	1	6.3000	63.0000
2536	2016-03-23 18:15:00	1	6.9000	48.0000
2537	2016-03-23 18:16:00	1	6.0000	56.0000
2538	2016-03-23 18:17:00	1	29.5000	52.0000
2539	2016-03-23 18:18:00	1	20.6000	70.0000
2540	2016-03-23 18:19:00	1	7.9000	40.0000
2541	2016-03-23 18:20:00	1	5.2000	59.0000
2542	2016-03-23 18:21:00	1	26.4000	58.0000
2543	2016-03-23 18:22:00	1	24.5000	63.0000
2544	2016-03-23 18:23:00	1	7.0000	55.0000
2545	2016-03-23 18:24:00	1	-0.6000	60.0000
2546	2016-03-23 18:25:00	1	-5.6000	54.0000
2547	2016-03-23 18:26:00	1	11.3000	74.0000
2548	2016-03-23 18:27:00	1	-4.7000	67.0000
2549	2016-03-23 18:28:00	1	-5.7000	61.0000
2550	2016-03-23 18:29:00	1	14.4000	42.0000
2551	2016-03-23 18:30:00	1	-4.7000	76.0000
2552	2016-03-23 18:31:00	1	12.0000	42.0000
2553	2016-03-23 18:32:00	1	27.4000	58.0000
2554	2016-03-23 18:33:00	1	7.5000	67.0000
2555	2016-03-23 18:34:00	1	27.0000	44.0000
2556	2016-03-23 18:35:00	1	22.5000	53.0000
2557	2016-03-23 18:36:00	1	19.2000	55.0000
2558	2016-03-23 18:37:00	1	19.1000	58.0000
2559	2016-03-23 18:38:00	1	13.8000	61.0000
2560	2016-03-23 18:39:00	1	1.9000	67.0000
2561	2016-03-23 18:40:00	1	-5.2000	50.0000
2562	2016-03-23 18:41:00	1	2.9000	47.0000
2563	2016-03-23 18:42:00	1	29.2000	74.0000
2564	2016-03-23 18:43:00	1	4.5000	40.0000
2565	2016-03-23 18:44:00	1	22.3000	72.0000
2566	2016-03-23 18:45:00	1	14.0000	60.0000
2567	2016-03-23 18:46:00	1	-9.9000	53.0000
2568	2016-03-23 18:47:00	1	8.9000	60.0000
2569	2016-03-23 18:48:00	1	17.5000	56.0000
2570	2016-03-23 18:49:00	1	15.6000	58.0000
2571	2016-03-23 18:50:00	1	21.8000	54.0000
2572	2016-03-23 18:51:00	1	26.7000	42.0000
2573	2016-03-23 18:52:00	1	-3.0000	63.0000
2574	2016-03-23 18:53:00	1	-5.3000	67.0000
2575	2016-03-23 18:54:00	1	22.0000	74.0000
2576	2016-03-23 18:55:00	1	13.9000	44.0000
2577	2016-03-23 18:56:00	1	23.0000	76.0000
2578	2016-03-23 18:57:00	1	12.8000	67.0000
2579	2016-03-23 18:58:00	1	5.0000	64.0000
2580	2016-03-23 18:59:00	1	25.6000	45.0000
2581	2016-03-23 19:00:00	1	26.2000	70.0000
2582	2016-03-23 19:01:00	1	-5.0000	44.0000
2583	2016-03-23 19:02:00	1	15.6000	46.0000
2584	2016-03-23 19:03:00	1	23.9000	53.0000
2585	2016-03-23 19:04:00	1	10.3000	50.0000
2586	2016-03-23 19:05:00	1	27.6000	41.0000
2587	2016-03-23 19:06:00	1	27.6000	63.0000
2588	2016-03-23 19:07:00	1	23.2000	72.0000
2589	2016-03-23 19:08:00	1	10.2000	44.0000
2590	2016-03-23 19:09:00	1	25.4000	69.0000
2591	2016-03-23 19:10:00	1	4.5000	74.0000
2592	2016-03-23 19:11:00	1	-1.1000	41.0000
2593	2016-03-23 19:12:00	1	6.1000	63.0000
2594	2016-03-23 19:13:00	1	29.7000	59.0000
2595	2016-03-23 19:14:00	1	19.0000	56.0000
2596	2016-03-23 19:15:00	1	28.4000	43.0000
2597	2016-03-23 19:16:00	1	5.0000	48.0000
2598	2016-03-23 19:17:00	1	11.4000	48.0000
2599	2016-03-23 19:18:00	1	17.3000	50.0000
2600	2016-03-23 19:19:00	1	3.7000	57.0000
2601	2016-03-23 19:20:00	1	24.8000	53.0000
2602	2016-03-23 19:21:00	1	9.8000	63.0000
2603	2016-03-23 19:22:00	1	-4.3000	41.0000
2604	2016-03-23 19:23:00	1	27.1000	63.0000
2605	2016-03-23 19:24:00	1	0.8000	75.0000
2606	2016-03-23 19:25:00	1	28.1000	43.0000
2607	2016-03-23 19:26:00	1	1.8000	65.0000
2608	2016-03-23 19:27:00	1	22.8000	79.0000
2609	2016-03-23 19:28:00	1	28.7000	71.0000
2610	2016-03-23 19:29:00	1	9.0000	75.0000
2611	2016-03-23 19:30:00	1	17.9000	42.0000
2612	2016-03-23 19:31:00	1	2.8000	72.0000
2613	2016-03-23 19:32:00	1	10.8000	63.0000
2614	2016-03-23 19:33:00	1	-6.6000	65.0000
2615	2016-03-23 19:34:00	1	-0.5000	42.0000
2616	2016-03-23 19:35:00	1	5.7000	52.0000
2617	2016-03-23 19:36:00	1	18.5000	40.0000
2618	2016-03-23 19:37:00	1	26.8000	71.0000
2619	2016-03-23 19:38:00	1	-1.6000	51.0000
2620	2016-03-23 19:39:00	1	10.2000	46.0000
2621	2016-03-23 19:40:00	1	16.3000	46.0000
2622	2016-03-23 19:41:00	1	-5.4000	56.0000
2623	2016-03-23 19:42:00	1	15.2000	52.0000
2624	2016-03-23 19:43:00	1	15.9000	58.0000
2625	2016-03-23 19:44:00	1	19.9000	72.0000
2626	2016-03-23 19:45:00	1	1.5000	70.0000
2627	2016-03-23 19:46:00	1	12.3000	50.0000
2628	2016-03-23 19:47:00	1	10.6000	44.0000
2629	2016-03-23 19:48:00	1	8.5000	42.0000
2630	2016-03-23 19:49:00	1	1.2000	67.0000
2631	2016-03-23 19:50:00	1	-8.8000	71.0000
2632	2016-03-23 19:51:00	1	22.3000	59.0000
2633	2016-03-23 19:52:00	1	12.4000	75.0000
2634	2016-03-23 19:53:00	1	14.0000	71.0000
2635	2016-03-23 19:54:00	1	12.9000	44.0000
2636	2016-03-23 19:55:00	1	0.0000	73.0000
2637	2016-03-23 19:56:00	1	12.5000	45.0000
2638	2016-03-23 19:57:00	1	-2.8000	61.0000
2639	2016-03-23 19:58:00	1	2.0000	43.0000
2640	2016-03-23 19:59:00	1	21.6000	60.0000
2641	2016-03-23 20:00:00	1	28.1000	52.0000
2642	2016-03-23 20:01:00	1	9.7000	50.0000
2643	2016-03-23 20:02:00	1	17.4000	52.0000
2644	2016-03-23 20:03:00	1	13.5000	77.0000
2645	2016-03-23 20:04:00	1	14.4000	63.0000
2646	2016-03-23 20:05:00	1	23.9000	79.0000
2647	2016-03-23 20:06:00	1	11.6000	63.0000
2648	2016-03-23 20:07:00	1	5.3000	64.0000
2649	2016-03-23 20:08:00	1	5.2000	48.0000
2650	2016-03-23 20:09:00	1	24.8000	64.0000
2651	2016-03-23 20:10:00	1	-6.4000	52.0000
2652	2016-03-23 20:11:00	1	-2.7000	43.0000
2653	2016-03-23 20:12:00	1	9.4000	45.0000
2654	2016-03-23 20:13:00	1	23.7000	55.0000
2655	2016-03-23 20:14:00	1	-2.3000	63.0000
2656	2016-03-23 20:15:00	1	23.3000	65.0000
2657	2016-03-23 20:16:00	1	18.4000	45.0000
2658	2016-03-23 20:17:00	1	16.2000	58.0000
2659	2016-03-23 20:18:00	1	3.4000	49.0000
2660	2016-03-23 20:19:00	1	11.7000	52.0000
2661	2016-03-23 20:20:00	1	-5.7000	58.0000
2662	2016-03-23 20:21:00	1	13.3000	67.0000
2663	2016-03-23 20:22:00	1	-8.3000	68.0000
2664	2016-03-23 20:23:00	1	19.9000	58.0000
2665	2016-03-23 20:24:00	1	28.0000	66.0000
2666	2016-03-23 20:25:00	1	5.1000	68.0000
2667	2016-03-23 20:26:00	1	19.5000	78.0000
2668	2016-03-23 20:27:00	1	17.6000	77.0000
2669	2016-03-23 20:28:00	1	27.0000	54.0000
2670	2016-03-23 20:29:00	1	-9.8000	52.0000
2671	2016-03-23 20:30:00	1	-3.3000	47.0000
2672	2016-03-23 20:31:00	1	0.5000	72.0000
2673	2016-03-23 20:32:00	1	-3.4000	72.0000
2674	2016-03-23 20:33:00	1	1.0000	70.0000
2675	2016-03-23 20:34:00	1	-3.7000	43.0000
2676	2016-03-23 20:35:00	1	7.7000	73.0000
2677	2016-03-23 20:36:00	1	-1.8000	52.0000
2678	2016-03-23 20:37:00	1	26.5000	41.0000
2679	2016-03-23 20:38:00	1	29.6000	71.0000
2680	2016-03-23 20:39:00	1	16.9000	56.0000
2681	2016-03-23 20:40:00	1	1.0000	60.0000
2682	2016-03-23 20:41:00	1	29.2000	56.0000
2683	2016-03-23 20:42:00	1	14.4000	55.0000
2684	2016-03-23 20:43:00	1	-0.7000	42.0000
2685	2016-03-23 20:44:00	1	-1.8000	45.0000
2686	2016-03-23 20:45:00	1	16.2000	65.0000
2687	2016-03-23 20:46:00	1	-6.9000	52.0000
2688	2016-03-23 20:47:00	1	0.0000	45.0000
2689	2016-03-23 20:48:00	1	23.4000	46.0000
2690	2016-03-23 20:49:00	1	19.6000	64.0000
2691	2016-03-23 20:50:00	1	3.7000	57.0000
2692	2016-03-23 20:51:00	1	0.4000	70.0000
2693	2016-03-23 20:52:00	1	-1.8000	57.0000
2694	2016-03-23 20:53:00	1	21.8000	69.0000
2695	2016-03-23 20:54:00	1	23.3000	50.0000
2696	2016-03-23 20:55:00	1	-4.5000	64.0000
2697	2016-03-23 20:56:00	1	10.8000	68.0000
2698	2016-03-23 20:57:00	1	-5.2000	69.0000
2699	2016-03-23 20:58:00	1	21.6000	73.0000
2700	2016-03-23 20:59:00	1	16.7000	52.0000
2701	2016-03-23 21:00:00	1	13.7000	65.0000
2702	2016-03-23 21:01:00	1	4.6000	51.0000
2703	2016-03-23 21:02:00	1	-0.4000	74.0000
2704	2016-03-23 21:03:00	1	26.5000	60.0000
2705	2016-03-23 21:04:00	1	-4.4000	71.0000
2706	2016-03-23 21:05:00	1	-7.2000	50.0000
2707	2016-03-23 21:06:00	1	23.4000	41.0000
2708	2016-03-23 21:07:00	1	-8.8000	76.0000
2709	2016-03-23 21:08:00	1	10.2000	51.0000
2710	2016-03-23 21:09:00	1	-0.5000	45.0000
2711	2016-03-23 21:10:00	1	1.8000	50.0000
2712	2016-03-23 21:11:00	1	7.8000	51.0000
2713	2016-03-23 21:12:00	1	9.8000	50.0000
2714	2016-03-23 21:13:00	1	27.8000	41.0000
2715	2016-03-23 21:14:00	1	26.8000	50.0000
2716	2016-03-23 21:15:00	1	1.1000	42.0000
2717	2016-03-23 21:16:00	1	27.3000	51.0000
2718	2016-03-23 21:17:00	1	-2.6000	53.0000
2719	2016-03-23 21:18:00	1	0.4000	48.0000
2720	2016-03-23 21:19:00	1	-0.1000	46.0000
2721	2016-03-23 21:20:00	1	20.0000	57.0000
2722	2016-03-23 21:21:00	1	25.3000	66.0000
2723	2016-03-23 21:22:00	1	16.0000	56.0000
2724	2016-03-23 21:23:00	1	14.9000	57.0000
2725	2016-03-23 21:24:00	1	19.6000	47.0000
2726	2016-03-23 21:25:00	1	9.6000	68.0000
2727	2016-03-23 21:26:00	1	-0.6000	52.0000
2728	2016-03-23 21:27:00	1	24.0000	55.0000
2729	2016-03-23 21:28:00	1	10.1000	59.0000
2730	2016-03-23 21:29:00	1	-9.5000	46.0000
2731	2016-03-23 21:30:00	1	6.3000	69.0000
2732	2016-03-23 21:31:00	1	27.5000	65.0000
2733	2016-03-23 21:32:00	1	27.2000	40.0000
2734	2016-03-23 21:33:00	1	10.5000	45.0000
2735	2016-03-23 21:34:00	1	-1.2000	71.0000
2736	2016-03-23 21:35:00	1	13.6000	48.0000
2737	2016-03-23 21:36:00	1	-6.8000	46.0000
2738	2016-03-23 21:37:00	1	12.0000	47.0000
2739	2016-03-23 21:38:00	1	5.4000	57.0000
2740	2016-03-23 21:39:00	1	25.3000	69.0000
2741	2016-03-23 21:40:00	1	-8.7000	65.0000
2742	2016-03-23 21:41:00	1	-3.6000	41.0000
2743	2016-03-23 21:42:00	1	2.4000	56.0000
2744	2016-03-23 21:43:00	1	29.9000	59.0000
2745	2016-03-23 21:44:00	1	22.3000	52.0000
2746	2016-03-23 21:45:00	1	-0.5000	45.0000
2747	2016-03-23 21:46:00	1	1.9000	53.0000
2748	2016-03-23 21:47:00	1	12.2000	41.0000
2749	2016-03-23 21:48:00	1	1.9000	68.0000
2750	2016-03-23 21:49:00	1	6.8000	42.0000
2751	2016-03-23 21:50:00	1	23.2000	56.0000
2752	2016-03-23 21:51:00	1	9.4000	48.0000
2753	2016-03-23 21:52:00	1	9.3000	64.0000
2754	2016-03-23 21:53:00	1	15.6000	43.0000
2755	2016-03-23 21:54:00	1	-1.6000	58.0000
2756	2016-03-23 21:55:00	1	29.7000	65.0000
2757	2016-03-23 21:56:00	1	25.9000	49.0000
2758	2016-03-23 21:57:00	1	10.5000	41.0000
2759	2016-03-23 21:58:00	1	-3.4000	62.0000
2760	2016-03-23 21:59:00	1	-9.2000	40.0000
2761	2016-03-23 22:00:00	1	10.8000	65.0000
2762	2016-03-23 22:01:00	1	-2.6000	55.0000
2763	2016-03-23 22:02:00	1	7.3000	75.0000
2764	2016-03-23 22:03:00	1	-8.0000	51.0000
2765	2016-03-23 22:04:00	1	22.2000	62.0000
2766	2016-03-23 22:05:00	1	-0.2000	63.0000
2767	2016-03-23 22:06:00	1	9.1000	43.0000
2768	2016-03-23 22:07:00	1	11.7000	60.0000
2769	2016-03-23 22:08:00	1	20.7000	45.0000
2770	2016-03-23 22:09:00	1	23.1000	48.0000
2771	2016-03-23 22:10:00	1	18.3000	55.0000
2772	2016-03-23 22:11:00	1	-1.2000	46.0000
2773	2016-03-23 22:12:00	1	29.0000	59.0000
2774	2016-03-23 22:13:00	1	22.5000	69.0000
2775	2016-03-23 22:14:00	1	-0.3000	67.0000
2776	2016-03-23 22:15:00	1	-5.6000	55.0000
2777	2016-03-23 22:16:00	1	-6.4000	73.0000
2778	2016-03-23 22:17:00	1	13.3000	50.0000
2779	2016-03-23 22:18:00	1	-8.7000	47.0000
2780	2016-03-23 22:19:00	1	0.0000	71.0000
2781	2016-03-23 22:20:00	1	-6.0000	54.0000
2782	2016-03-23 22:21:00	1	8.9000	66.0000
2783	2016-03-23 22:22:00	1	-0.9000	64.0000
2784	2016-03-23 22:23:00	1	11.5000	64.0000
2785	2016-03-23 22:24:00	1	-2.1000	49.0000
2786	2016-03-23 22:25:00	1	28.8000	72.0000
2787	2016-03-23 22:26:00	1	-2.6000	45.0000
2788	2016-03-23 22:27:00	1	10.3000	69.0000
2789	2016-03-23 22:28:00	1	26.8000	65.0000
2790	2016-03-23 22:29:00	1	1.8000	65.0000
2791	2016-03-23 22:30:00	1	-3.9000	46.0000
2792	2016-03-23 22:31:00	1	27.0000	45.0000
2793	2016-03-23 22:32:00	1	18.0000	70.0000
2794	2016-03-23 22:33:00	1	20.4000	47.0000
2795	2016-03-23 22:34:00	1	-4.5000	56.0000
2796	2016-03-23 22:35:00	1	12.7000	65.0000
2797	2016-03-23 22:36:00	1	10.3000	72.0000
2798	2016-03-23 22:37:00	1	22.5000	47.0000
2799	2016-03-23 22:38:00	1	-7.8000	57.0000
2800	2016-03-23 22:39:00	1	19.1000	65.0000
2801	2016-03-23 22:40:00	1	18.6000	43.0000
2802	2016-03-23 22:41:00	1	-3.7000	72.0000
2803	2016-03-23 22:42:00	1	25.4000	75.0000
2804	2016-03-23 22:43:00	1	-7.8000	71.0000
2805	2016-03-23 22:44:00	1	29.4000	77.0000
2806	2016-03-23 22:45:00	1	28.7000	53.0000
2807	2016-03-23 22:46:00	1	20.3000	76.0000
2808	2016-03-23 22:47:00	1	5.1000	62.0000
2809	2016-03-23 22:48:00	1	6.0000	73.0000
2810	2016-03-23 22:49:00	1	-2.6000	62.0000
2811	2016-03-23 22:50:00	1	-4.1000	47.0000
2812	2016-03-23 22:51:00	1	20.9000	79.0000
2813	2016-03-23 22:52:00	1	21.7000	78.0000
2814	2016-03-23 22:53:00	1	5.6000	55.0000
2815	2016-03-23 22:54:00	1	27.5000	56.0000
2816	2016-03-23 22:55:00	1	-6.0000	63.0000
2817	2016-03-23 22:56:00	1	22.6000	77.0000
2818	2016-03-23 22:57:00	1	12.0000	67.0000
2819	2016-03-23 22:58:00	1	26.9000	54.0000
2820	2016-03-23 22:59:00	1	10.2000	52.0000
2821	2016-03-23 23:00:00	1	28.2000	74.0000
2822	2016-03-23 23:01:00	1	-8.3000	55.0000
2823	2016-03-23 23:02:00	1	4.7000	62.0000
2824	2016-03-23 23:03:00	1	-3.3000	75.0000
2825	2016-03-23 23:04:00	1	12.3000	45.0000
2826	2016-03-23 23:05:00	1	2.1000	63.0000
2827	2016-03-23 23:06:00	1	-5.7000	44.0000
2828	2016-03-23 23:07:00	1	4.4000	52.0000
2829	2016-03-23 23:08:00	1	16.6000	67.0000
2830	2016-03-23 23:09:00	1	20.0000	78.0000
2831	2016-03-23 23:10:00	1	24.8000	47.0000
2832	2016-03-23 23:11:00	1	0.1000	63.0000
2833	2016-03-23 23:12:00	1	-5.8000	75.0000
2834	2016-03-23 23:13:00	1	5.4000	56.0000
2835	2016-03-23 23:14:00	1	6.3000	68.0000
2836	2016-03-23 23:15:00	1	27.4000	61.0000
2837	2016-03-23 23:16:00	1	4.6000	52.0000
2838	2016-03-23 23:17:00	1	-7.0000	71.0000
2839	2016-03-23 23:18:00	1	5.9000	53.0000
2840	2016-03-23 23:19:00	1	9.9000	68.0000
2841	2016-03-23 23:20:00	1	13.8000	43.0000
2842	2016-03-23 23:21:00	1	16.4000	51.0000
2843	2016-03-23 23:22:00	1	25.1000	52.0000
2844	2016-03-23 23:23:00	1	14.2000	70.0000
2845	2016-03-23 23:24:00	1	20.9000	49.0000
2846	2016-03-23 23:25:00	1	-4.3000	43.0000
2847	2016-03-23 23:26:00	1	-1.9000	50.0000
2848	2016-03-23 23:27:00	1	3.0000	61.0000
2849	2016-03-23 23:28:00	1	-2.0000	55.0000
2850	2016-03-23 23:29:00	1	3.4000	54.0000
2851	2016-03-23 23:30:00	1	14.0000	45.0000
2852	2016-03-23 23:31:00	1	28.7000	64.0000
2853	2016-03-23 23:32:00	1	-0.1000	52.0000
2854	2016-03-23 23:33:00	1	17.8000	51.0000
2855	2016-03-23 23:34:00	1	1.3000	41.0000
2856	2016-03-23 23:35:00	1	13.9000	44.0000
2857	2016-03-23 23:36:00	1	29.7000	69.0000
2858	2016-03-23 23:37:00	1	13.2000	51.0000
2859	2016-03-23 23:38:00	1	1.1000	57.0000
2860	2016-03-23 23:39:00	1	6.5000	40.0000
2861	2016-03-23 23:40:00	1	11.5000	70.0000
2862	2016-03-23 23:41:00	1	17.6000	43.0000
2863	2016-03-23 23:42:00	1	28.2000	68.0000
2864	2016-03-23 23:43:00	1	-8.1000	45.0000
2865	2016-03-23 23:44:00	1	18.9000	42.0000
2866	2016-03-23 23:45:00	1	20.3000	65.0000
2867	2016-03-23 23:46:00	1	16.2000	55.0000
2868	2016-03-23 23:47:00	1	1.4000	44.0000
2869	2016-03-23 23:48:00	1	20.7000	64.0000
2870	2016-03-23 23:49:00	1	11.8000	52.0000
2871	2016-03-23 23:50:00	1	-3.1000	53.0000
2872	2016-03-23 23:51:00	1	27.1000	69.0000
2873	2016-03-23 23:52:00	1	6.1000	70.0000
2874	2016-03-23 23:53:00	1	-8.5000	43.0000
2875	2016-03-23 23:54:00	1	17.8000	62.0000
2876	2016-03-23 23:55:00	1	19.1000	73.0000
2877	2016-03-23 23:56:00	1	-9.7000	46.0000
2878	2016-03-23 23:57:00	1	28.9000	72.0000
2879	2016-03-23 23:58:00	1	7.2000	40.0000
2880	2016-03-23 23:59:00	1	-5.4000	77.0000
2881	2016-03-24 00:00:00	1	7.6000	49.0000
2882	2016-03-24 00:01:00	1	3.4000	40.0000
2883	2016-03-24 00:02:00	1	1.5000	70.0000
2884	2016-03-24 00:03:00	1	-2.6000	62.0000
2885	2016-03-24 00:04:00	1	-0.5000	59.0000
2886	2016-03-24 00:05:00	1	29.9000	46.0000
2887	2016-03-24 00:06:00	1	19.8000	45.0000
2888	2016-03-24 00:07:00	1	18.5000	70.0000
2889	2016-03-24 00:08:00	1	-2.3000	68.0000
2890	2016-03-24 00:09:00	1	-6.0000	43.0000
2891	2016-03-24 00:10:00	1	12.9000	53.0000
2892	2016-03-24 00:11:00	1	18.8000	78.0000
2893	2016-03-24 00:12:00	1	23.7000	44.0000
2894	2016-03-24 00:13:00	1	-6.9000	60.0000
2895	2016-03-24 00:14:00	1	8.9000	55.0000
2896	2016-03-24 00:15:00	1	25.1000	64.0000
2897	2016-03-24 00:16:00	1	27.9000	41.0000
2898	2016-03-24 00:17:00	1	22.2000	41.0000
2899	2016-03-24 00:18:00	1	20.8000	48.0000
2900	2016-03-24 00:19:00	1	15.1000	40.0000
2901	2016-03-24 00:20:00	1	19.5000	63.0000
2902	2016-03-24 00:21:00	1	11.7000	58.0000
2903	2016-03-24 00:22:00	1	24.1000	49.0000
2904	2016-03-24 00:23:00	1	-7.9000	72.0000
2905	2016-03-24 00:24:00	1	-1.3000	65.0000
2906	2016-03-24 00:25:00	1	18.2000	59.0000
2907	2016-03-24 00:26:00	1	5.9000	54.0000
2908	2016-03-24 00:27:00	1	1.1000	65.0000
2909	2016-03-24 00:28:00	1	2.4000	49.0000
2910	2016-03-24 00:29:00	1	3.8000	51.0000
2911	2016-03-24 00:30:00	1	-6.7000	45.0000
2912	2016-03-24 00:31:00	1	17.8000	68.0000
2913	2016-03-24 00:32:00	1	7.4000	78.0000
2914	2016-03-24 00:33:00	1	0.6000	57.0000
2915	2016-03-24 00:34:00	1	9.7000	52.0000
2916	2016-03-24 00:35:00	1	-1.4000	73.0000
2917	2016-03-24 00:36:00	1	10.8000	63.0000
2918	2016-03-24 00:37:00	1	18.6000	41.0000
2919	2016-03-24 00:38:00	1	-9.5000	79.0000
2920	2016-03-24 00:39:00	1	6.5000	49.0000
2921	2016-03-24 00:40:00	1	26.7000	48.0000
2922	2016-03-24 00:41:00	1	-9.1000	61.0000
2923	2016-03-24 00:42:00	1	11.8000	45.0000
2924	2016-03-24 00:43:00	1	12.2000	79.0000
2925	2016-03-24 00:44:00	1	16.2000	72.0000
2926	2016-03-24 00:45:00	1	15.5000	59.0000
2927	2016-03-24 00:46:00	1	-5.1000	65.0000
2928	2016-03-24 00:47:00	1	20.7000	42.0000
2929	2016-03-24 00:48:00	1	23.4000	56.0000
2930	2016-03-24 00:49:00	1	20.6000	69.0000
2931	2016-03-24 00:50:00	1	26.9000	76.0000
2932	2016-03-24 00:51:00	1	12.4000	42.0000
2933	2016-03-24 00:52:00	1	19.6000	53.0000
2934	2016-03-24 00:53:00	1	22.5000	51.0000
2935	2016-03-24 00:54:00	1	-8.4000	57.0000
2936	2016-03-24 00:55:00	1	29.3000	56.0000
2937	2016-03-24 00:56:00	1	3.8000	48.0000
2938	2016-03-24 00:57:00	1	1.0000	48.0000
2939	2016-03-24 00:58:00	1	2.2000	63.0000
2940	2016-03-24 00:59:00	1	19.8000	48.0000
2941	2016-03-24 01:00:00	1	19.2000	58.0000
2942	2016-03-24 01:01:00	1	18.0000	51.0000
2943	2016-03-24 01:02:00	1	18.6000	54.0000
2944	2016-03-24 01:03:00	1	6.5000	66.0000
2945	2016-03-24 01:04:00	1	9.9000	53.0000
2946	2016-03-24 01:05:00	1	25.1000	58.0000
2947	2016-03-24 01:06:00	1	-3.7000	78.0000
2948	2016-03-24 01:07:00	1	24.5000	68.0000
2949	2016-03-24 01:08:00	1	18.5000	43.0000
2950	2016-03-24 01:09:00	1	16.0000	43.0000
2951	2016-03-24 01:10:00	1	26.1000	59.0000
2952	2016-03-24 01:11:00	1	18.5000	45.0000
2953	2016-03-24 01:12:00	1	15.4000	76.0000
2954	2016-03-24 01:13:00	1	-4.5000	40.0000
2955	2016-03-24 01:14:00	1	22.6000	40.0000
2956	2016-03-24 01:15:00	1	26.1000	54.0000
2957	2016-03-24 01:16:00	1	0.6000	54.0000
2958	2016-03-24 01:17:00	1	5.9000	60.0000
2959	2016-03-24 01:18:00	1	-7.3000	59.0000
2960	2016-03-24 01:19:00	1	11.2000	58.0000
2961	2016-03-24 01:20:00	1	29.5000	62.0000
2962	2016-03-24 01:21:00	1	29.4000	61.0000
2963	2016-03-24 01:22:00	1	23.8000	75.0000
2964	2016-03-24 01:23:00	1	-8.3000	50.0000
2965	2016-03-24 01:24:00	1	11.0000	47.0000
2966	2016-03-24 01:25:00	1	2.3000	58.0000
2967	2016-03-24 01:26:00	1	2.9000	72.0000
2968	2016-03-24 01:27:00	1	16.9000	52.0000
2969	2016-03-24 01:28:00	1	-9.8000	55.0000
2970	2016-03-24 01:29:00	1	26.0000	47.0000
2971	2016-03-24 01:30:00	1	17.8000	79.0000
2972	2016-03-24 01:31:00	1	4.7000	52.0000
2973	2016-03-24 01:32:00	1	6.2000	47.0000
2974	2016-03-24 01:33:00	1	27.6000	62.0000
2975	2016-03-24 01:34:00	1	13.0000	58.0000
2976	2016-03-24 01:35:00	1	-8.5000	58.0000
2977	2016-03-24 01:36:00	1	25.0000	56.0000
2978	2016-03-24 01:37:00	1	18.2000	59.0000
2979	2016-03-24 01:38:00	1	24.8000	67.0000
2980	2016-03-24 01:39:00	1	1.0000	50.0000
2981	2016-03-24 01:40:00	1	7.6000	42.0000
2982	2016-03-24 01:41:00	1	22.8000	59.0000
2983	2016-03-24 01:42:00	1	14.0000	70.0000
2984	2016-03-24 01:43:00	1	18.7000	42.0000
2985	2016-03-24 01:44:00	1	2.2000	42.0000
2986	2016-03-24 01:45:00	1	7.1000	40.0000
2987	2016-03-24 01:46:00	1	6.8000	51.0000
2988	2016-03-24 01:47:00	1	28.3000	55.0000
2989	2016-03-24 01:48:00	1	12.4000	44.0000
2990	2016-03-24 01:49:00	1	1.8000	45.0000
2991	2016-03-24 01:50:00	1	4.6000	57.0000
2992	2016-03-24 01:51:00	1	17.8000	41.0000
2993	2016-03-24 01:52:00	1	4.1000	62.0000
2994	2016-03-24 01:53:00	1	28.4000	65.0000
2995	2016-03-24 01:54:00	1	-4.0000	69.0000
2996	2016-03-24 01:55:00	1	14.7000	62.0000
2997	2016-03-24 01:56:00	1	22.6000	62.0000
2998	2016-03-24 01:57:00	1	4.0000	46.0000
2999	2016-03-24 01:58:00	1	27.3000	72.0000
3000	2016-03-24 01:59:00	1	-9.1000	77.0000
3001	2016-03-24 02:00:00	1	17.4000	58.0000
3002	2016-03-24 02:01:00	1	-0.5000	76.0000
3003	2016-03-24 02:02:00	1	-0.3000	69.0000
3004	2016-03-24 02:03:00	1	27.1000	67.0000
3005	2016-03-24 02:04:00	1	-6.3000	49.0000
3006	2016-03-24 02:05:00	1	27.5000	54.0000
3007	2016-03-24 02:06:00	1	12.2000	55.0000
3008	2016-03-24 02:07:00	1	17.9000	60.0000
3009	2016-03-24 02:08:00	1	-8.6000	55.0000
3010	2016-03-24 02:09:00	1	-4.7000	65.0000
3011	2016-03-24 02:10:00	1	25.6000	59.0000
3012	2016-03-24 02:11:00	1	21.0000	55.0000
3013	2016-03-24 02:12:00	1	-2.4000	48.0000
3014	2016-03-24 02:13:00	1	-5.1000	52.0000
3015	2016-03-24 02:14:00	1	-2.4000	49.0000
3016	2016-03-24 02:15:00	1	4.4000	76.0000
3017	2016-03-24 02:16:00	1	13.8000	46.0000
3018	2016-03-24 02:17:00	1	29.2000	75.0000
3019	2016-03-24 02:18:00	1	21.7000	64.0000
3020	2016-03-24 02:19:00	1	15.6000	68.0000
3021	2016-03-24 02:20:00	1	-4.8000	54.0000
3022	2016-03-24 02:21:00	1	3.7000	59.0000
3023	2016-03-24 02:22:00	1	-1.5000	56.0000
3024	2016-03-24 02:23:00	1	13.7000	45.0000
3025	2016-03-24 02:24:00	1	17.9000	63.0000
3026	2016-03-24 02:25:00	1	7.3000	74.0000
3027	2016-03-24 02:26:00	1	9.0000	57.0000
3028	2016-03-24 02:27:00	1	1.8000	63.0000
3029	2016-03-24 02:28:00	1	3.2000	50.0000
3030	2016-03-24 02:29:00	1	21.5000	46.0000
3031	2016-03-24 02:30:00	1	12.5000	45.0000
3032	2016-03-24 02:31:00	1	5.9000	45.0000
3033	2016-03-24 02:32:00	1	19.8000	74.0000
3034	2016-03-24 02:33:00	1	29.8000	46.0000
3035	2016-03-24 02:34:00	1	1.3000	63.0000
3036	2016-03-24 02:35:00	1	6.9000	70.0000
3037	2016-03-24 02:36:00	1	-1.4000	55.0000
3038	2016-03-24 02:37:00	1	-6.1000	46.0000
3039	2016-03-24 02:38:00	1	22.3000	47.0000
3040	2016-03-24 02:39:00	1	17.0000	42.0000
3041	2016-03-24 02:40:00	1	6.7000	60.0000
3042	2016-03-24 02:41:00	1	-6.2000	72.0000
3043	2016-03-24 02:42:00	1	2.6000	66.0000
3044	2016-03-24 02:43:00	1	12.3000	43.0000
3045	2016-03-24 02:44:00	1	22.4000	69.0000
3046	2016-03-24 02:45:00	1	-3.4000	53.0000
3047	2016-03-24 02:46:00	1	9.7000	70.0000
3048	2016-03-24 02:47:00	1	11.3000	65.0000
3049	2016-03-24 02:48:00	1	27.5000	58.0000
3050	2016-03-24 02:49:00	1	21.0000	61.0000
3051	2016-03-24 02:50:00	1	-3.4000	65.0000
3052	2016-03-24 02:51:00	1	15.3000	78.0000
3053	2016-03-24 02:52:00	1	28.6000	59.0000
3054	2016-03-24 02:53:00	1	22.2000	51.0000
3055	2016-03-24 02:54:00	1	6.8000	74.0000
3056	2016-03-24 02:55:00	1	1.2000	55.0000
3057	2016-03-24 02:56:00	1	13.4000	70.0000
3058	2016-03-24 02:57:00	1	19.2000	72.0000
3059	2016-03-24 02:58:00	1	20.7000	41.0000
3060	2016-03-24 02:59:00	1	11.7000	50.0000
3061	2016-03-24 03:00:00	1	15.4000	63.0000
3062	2016-03-24 03:01:00	1	28.1000	45.0000
3063	2016-03-24 03:02:00	1	0.9000	42.0000
3064	2016-03-24 03:03:00	1	4.6000	57.0000
3065	2016-03-24 03:04:00	1	-9.5000	41.0000
3066	2016-03-24 03:05:00	1	7.2000	61.0000
3067	2016-03-24 03:06:00	1	3.5000	68.0000
3068	2016-03-24 03:07:00	1	12.2000	45.0000
3069	2016-03-24 03:08:00	1	21.7000	61.0000
3070	2016-03-24 03:09:00	1	-7.0000	73.0000
3071	2016-03-24 03:10:00	1	23.6000	69.0000
3072	2016-03-24 03:11:00	1	-7.9000	50.0000
3073	2016-03-24 03:12:00	1	19.2000	55.0000
3074	2016-03-24 03:13:00	1	3.0000	74.0000
3075	2016-03-24 03:14:00	1	-7.1000	55.0000
3076	2016-03-24 03:15:00	1	-7.0000	47.0000
3077	2016-03-24 03:16:00	1	13.1000	68.0000
3078	2016-03-24 03:17:00	1	23.4000	51.0000
3079	2016-03-24 03:18:00	1	10.5000	41.0000
3080	2016-03-24 03:19:00	1	-7.7000	50.0000
3081	2016-03-24 03:20:00	1	3.5000	46.0000
3082	2016-03-24 03:21:00	1	18.1000	67.0000
3083	2016-03-24 03:22:00	1	12.0000	49.0000
3084	2016-03-24 03:23:00	1	29.1000	61.0000
3085	2016-03-24 03:24:00	1	14.8000	68.0000
3086	2016-03-24 03:25:00	1	12.2000	66.0000
3087	2016-03-24 03:26:00	1	6.3000	62.0000
3088	2016-03-24 03:27:00	1	25.4000	77.0000
3089	2016-03-24 03:28:00	1	5.6000	77.0000
3090	2016-03-24 03:29:00	1	15.3000	74.0000
3091	2016-03-24 03:30:00	1	-6.9000	75.0000
3092	2016-03-24 03:31:00	1	-3.2000	71.0000
3093	2016-03-24 03:32:00	1	19.5000	52.0000
3094	2016-03-24 03:33:00	1	10.1000	53.0000
3095	2016-03-24 03:34:00	1	-1.9000	70.0000
3096	2016-03-24 03:35:00	1	21.0000	54.0000
3097	2016-03-24 03:36:00	1	-8.2000	54.0000
3098	2016-03-24 03:37:00	1	-1.4000	50.0000
3099	2016-03-24 03:38:00	1	19.5000	73.0000
3100	2016-03-24 03:39:00	1	27.5000	73.0000
3101	2016-03-24 03:40:00	1	-0.3000	66.0000
3102	2016-03-24 03:41:00	1	22.7000	59.0000
3103	2016-03-24 03:42:00	1	-6.0000	75.0000
3104	2016-03-24 03:43:00	1	21.5000	46.0000
3105	2016-03-24 03:44:00	1	26.5000	46.0000
3106	2016-03-24 03:45:00	1	28.1000	44.0000
3107	2016-03-24 03:46:00	1	-4.9000	40.0000
3108	2016-03-24 03:47:00	1	15.7000	43.0000
3109	2016-03-24 03:48:00	1	-5.0000	57.0000
3110	2016-03-24 03:49:00	1	-5.4000	45.0000
3111	2016-03-24 03:50:00	1	18.1000	40.0000
3112	2016-03-24 03:51:00	1	24.7000	63.0000
3113	2016-03-24 03:52:00	1	4.8000	60.0000
3114	2016-03-24 03:53:00	1	3.8000	76.0000
3115	2016-03-24 03:54:00	1	1.0000	45.0000
3116	2016-03-24 03:55:00	1	8.7000	54.0000
3117	2016-03-24 03:56:00	1	20.9000	49.0000
3118	2016-03-24 03:57:00	1	-3.3000	79.0000
3119	2016-03-24 03:58:00	1	29.5000	68.0000
3120	2016-03-24 03:59:00	1	4.5000	56.0000
3121	2016-03-24 04:00:00	1	5.0000	45.0000
3122	2016-03-24 04:01:00	1	25.6000	54.0000
3123	2016-03-24 04:02:00	1	7.4000	54.0000
3124	2016-03-24 04:03:00	1	4.7000	58.0000
3125	2016-03-24 04:04:00	1	17.0000	74.0000
3126	2016-03-24 04:05:00	1	25.6000	78.0000
3127	2016-03-24 04:06:00	1	4.9000	63.0000
3128	2016-03-24 04:07:00	1	-5.0000	47.0000
3129	2016-03-24 04:08:00	1	23.6000	54.0000
3130	2016-03-24 04:09:00	1	24.0000	76.0000
3131	2016-03-24 04:10:00	1	20.1000	53.0000
3132	2016-03-24 04:11:00	1	15.3000	50.0000
3133	2016-03-24 04:12:00	1	14.1000	63.0000
3134	2016-03-24 04:13:00	1	5.9000	46.0000
3135	2016-03-24 04:14:00	1	20.2000	55.0000
3136	2016-03-24 04:15:00	1	9.7000	65.0000
3137	2016-03-24 04:16:00	1	-7.0000	62.0000
3138	2016-03-24 04:17:00	1	15.2000	46.0000
3139	2016-03-24 04:18:00	1	26.5000	56.0000
3140	2016-03-24 04:19:00	1	-7.1000	46.0000
3141	2016-03-24 04:20:00	1	9.1000	48.0000
3142	2016-03-24 04:21:00	1	28.5000	63.0000
3143	2016-03-24 04:22:00	1	18.8000	44.0000
3144	2016-03-24 04:23:00	1	13.7000	74.0000
3145	2016-03-24 04:24:00	1	12.4000	54.0000
3146	2016-03-24 04:25:00	1	17.0000	57.0000
3147	2016-03-24 04:26:00	1	20.4000	41.0000
3148	2016-03-24 04:27:00	1	23.5000	49.0000
3149	2016-03-24 04:28:00	1	-5.7000	77.0000
3150	2016-03-24 04:29:00	1	28.2000	75.0000
3151	2016-03-24 04:30:00	1	29.9000	78.0000
3152	2016-03-24 04:31:00	1	29.6000	52.0000
3153	2016-03-24 04:32:00	1	23.0000	58.0000
3154	2016-03-24 04:33:00	1	13.4000	55.0000
3155	2016-03-24 04:34:00	1	14.7000	43.0000
3156	2016-03-24 04:35:00	1	3.0000	44.0000
3157	2016-03-24 04:36:00	1	14.8000	45.0000
3158	2016-03-24 04:37:00	1	27.8000	41.0000
3159	2016-03-24 04:38:00	1	5.1000	58.0000
3160	2016-03-24 04:39:00	1	26.0000	48.0000
3161	2016-03-24 04:40:00	1	29.2000	66.0000
3162	2016-03-24 04:41:00	1	0.0000	79.0000
3163	2016-03-24 04:42:00	1	25.3000	72.0000
3164	2016-03-24 04:43:00	1	-5.9000	52.0000
3165	2016-03-24 04:44:00	1	2.9000	64.0000
3166	2016-03-24 04:45:00	1	24.0000	41.0000
3167	2016-03-24 04:46:00	1	10.1000	47.0000
3168	2016-03-24 04:47:00	1	5.7000	41.0000
3169	2016-03-24 04:48:00	1	8.4000	72.0000
3170	2016-03-24 04:49:00	1	-7.4000	40.0000
3171	2016-03-24 04:50:00	1	15.3000	58.0000
3172	2016-03-24 04:51:00	1	-3.2000	45.0000
3173	2016-03-24 04:52:00	1	17.1000	72.0000
3174	2016-03-24 04:53:00	1	13.7000	72.0000
3175	2016-03-24 04:54:00	1	16.2000	42.0000
3176	2016-03-24 04:55:00	1	29.7000	43.0000
3177	2016-03-24 04:56:00	1	-7.3000	45.0000
3178	2016-03-24 04:57:00	1	5.0000	76.0000
3179	2016-03-24 04:58:00	1	3.1000	50.0000
3180	2016-03-24 04:59:00	1	27.6000	67.0000
3181	2016-03-24 05:00:00	1	11.4000	55.0000
3182	2016-03-24 05:01:00	1	28.8000	56.0000
3183	2016-03-24 05:02:00	1	15.2000	61.0000
3184	2016-03-24 05:03:00	1	4.6000	48.0000
3185	2016-03-24 05:04:00	1	3.4000	74.0000
3186	2016-03-24 05:05:00	1	-3.4000	48.0000
3187	2016-03-24 05:06:00	1	22.8000	73.0000
3188	2016-03-24 05:07:00	1	-1.1000	54.0000
3189	2016-03-24 05:08:00	1	8.2000	79.0000
3190	2016-03-24 05:09:00	1	12.1000	76.0000
3191	2016-03-24 05:10:00	1	2.4000	66.0000
3192	2016-03-24 05:11:00	1	19.7000	50.0000
3193	2016-03-24 05:12:00	1	21.5000	40.0000
3194	2016-03-24 05:13:00	1	3.2000	68.0000
3195	2016-03-24 05:14:00	1	13.8000	53.0000
3196	2016-03-24 05:15:00	1	20.6000	45.0000
3197	2016-03-24 05:16:00	1	-7.6000	63.0000
3198	2016-03-24 05:17:00	1	-3.4000	51.0000
3199	2016-03-24 05:18:00	1	-6.2000	78.0000
3200	2016-03-24 05:19:00	1	21.2000	78.0000
3201	2016-03-24 05:20:00	1	28.5000	68.0000
3202	2016-03-24 05:21:00	1	6.0000	43.0000
3203	2016-03-24 05:22:00	1	1.3000	58.0000
3204	2016-03-24 05:23:00	1	1.3000	47.0000
3205	2016-03-24 05:24:00	1	7.6000	43.0000
3206	2016-03-24 05:25:00	1	23.8000	59.0000
3207	2016-03-24 05:26:00	1	5.3000	62.0000
3208	2016-03-24 05:27:00	1	-4.8000	61.0000
3209	2016-03-24 05:28:00	1	18.2000	54.0000
3210	2016-03-24 05:29:00	1	1.4000	73.0000
3211	2016-03-24 05:30:00	1	19.1000	44.0000
3212	2016-03-24 05:31:00	1	7.2000	55.0000
3213	2016-03-24 05:32:00	1	21.5000	78.0000
3214	2016-03-24 05:33:00	1	9.1000	72.0000
3215	2016-03-24 05:34:00	1	-4.9000	45.0000
3216	2016-03-24 05:35:00	1	2.5000	68.0000
3217	2016-03-24 05:36:00	1	-1.9000	55.0000
3218	2016-03-24 05:37:00	1	24.9000	54.0000
3219	2016-03-24 05:38:00	1	3.5000	69.0000
3220	2016-03-24 05:39:00	1	-1.2000	71.0000
3221	2016-03-24 05:40:00	1	29.5000	44.0000
3222	2016-03-24 05:41:00	1	11.2000	61.0000
3223	2016-03-24 05:42:00	1	16.1000	59.0000
3224	2016-03-24 05:43:00	1	11.6000	69.0000
3225	2016-03-24 05:44:00	1	-5.2000	51.0000
3226	2016-03-24 05:45:00	1	16.3000	59.0000
3227	2016-03-24 05:46:00	1	25.0000	40.0000
3228	2016-03-24 05:47:00	1	15.4000	63.0000
3229	2016-03-24 05:48:00	1	17.3000	40.0000
3230	2016-03-24 05:49:00	1	11.7000	75.0000
3231	2016-03-24 05:50:00	1	4.8000	43.0000
3232	2016-03-24 05:51:00	1	25.9000	78.0000
3233	2016-03-24 05:52:00	1	12.8000	55.0000
3234	2016-03-24 05:53:00	1	-7.8000	52.0000
3235	2016-03-24 05:54:00	1	26.9000	53.0000
3236	2016-03-24 05:55:00	1	17.5000	56.0000
3237	2016-03-24 05:56:00	1	3.6000	73.0000
3238	2016-03-24 05:57:00	1	1.2000	64.0000
3239	2016-03-24 05:58:00	1	25.1000	59.0000
3240	2016-03-24 05:59:00	1	3.9000	64.0000
3241	2016-03-24 06:00:00	1	15.7000	76.0000
3242	2016-03-24 06:01:00	1	23.8000	46.0000
3243	2016-03-24 06:02:00	1	-6.4000	58.0000
3244	2016-03-24 06:03:00	1	-2.8000	75.0000
3245	2016-03-24 06:04:00	1	13.8000	63.0000
3246	2016-03-24 06:05:00	1	13.2000	64.0000
3247	2016-03-24 06:06:00	1	13.2000	74.0000
3248	2016-03-24 06:07:00	1	11.4000	65.0000
3249	2016-03-24 06:08:00	1	-0.2000	74.0000
3250	2016-03-24 06:09:00	1	-7.6000	73.0000
3251	2016-03-24 06:10:00	1	24.7000	79.0000
3252	2016-03-24 06:11:00	1	-6.9000	65.0000
3253	2016-03-24 06:12:00	1	28.6000	45.0000
3254	2016-03-24 06:13:00	1	-2.2000	43.0000
3255	2016-03-24 06:14:00	1	-2.9000	62.0000
3256	2016-03-24 06:15:00	1	23.6000	55.0000
3257	2016-03-24 06:16:00	1	11.8000	51.0000
3258	2016-03-24 06:17:00	1	3.6000	75.0000
3259	2016-03-24 06:18:00	1	-3.3000	50.0000
3260	2016-03-24 06:19:00	1	6.2000	47.0000
3261	2016-03-24 06:20:00	1	-0.2000	40.0000
3262	2016-03-24 06:21:00	1	19.1000	79.0000
3263	2016-03-24 06:22:00	1	8.5000	73.0000
3264	2016-03-24 06:23:00	1	29.1000	43.0000
3265	2016-03-24 06:24:00	1	24.2000	40.0000
3266	2016-03-24 06:25:00	1	25.1000	75.0000
3267	2016-03-24 06:26:00	1	21.4000	44.0000
3268	2016-03-24 06:27:00	1	27.1000	71.0000
3269	2016-03-24 06:28:00	1	2.5000	48.0000
3270	2016-03-24 06:29:00	1	13.8000	54.0000
3271	2016-03-24 06:30:00	1	16.6000	42.0000
3272	2016-03-24 06:31:00	1	2.4000	69.0000
3273	2016-03-24 06:32:00	1	-5.1000	51.0000
3274	2016-03-24 06:33:00	1	23.7000	61.0000
3275	2016-03-24 06:34:00	1	-3.2000	53.0000
3276	2016-03-24 06:35:00	1	-7.9000	74.0000
3277	2016-03-24 06:36:00	1	-0.6000	79.0000
3278	2016-03-24 06:37:00	1	-0.4000	47.0000
3279	2016-03-24 06:38:00	1	-8.3000	77.0000
3280	2016-03-24 06:39:00	1	6.3000	60.0000
3281	2016-03-24 06:40:00	1	0.2000	45.0000
3282	2016-03-24 06:41:00	1	14.7000	56.0000
3283	2016-03-24 06:42:00	1	-0.4000	74.0000
3284	2016-03-24 06:43:00	1	21.7000	58.0000
3285	2016-03-24 06:44:00	1	16.6000	62.0000
3286	2016-03-24 06:45:00	1	-8.2000	73.0000
3287	2016-03-24 06:46:00	1	22.9000	61.0000
3288	2016-03-24 06:47:00	1	11.6000	76.0000
3289	2016-03-24 06:48:00	1	-9.8000	46.0000
3290	2016-03-24 06:49:00	1	-0.6000	73.0000
3291	2016-03-24 06:50:00	1	15.3000	65.0000
3292	2016-03-24 06:51:00	1	13.5000	71.0000
3293	2016-03-24 06:52:00	1	-7.4000	79.0000
3294	2016-03-24 06:53:00	1	12.6000	56.0000
3295	2016-03-24 06:54:00	1	-8.2000	48.0000
3296	2016-03-24 06:55:00	1	-9.8000	53.0000
3297	2016-03-24 06:56:00	1	0.3000	50.0000
3298	2016-03-24 06:57:00	1	3.5000	62.0000
3299	2016-03-24 06:58:00	1	-3.4000	77.0000
3300	2016-03-24 06:59:00	1	-7.9000	67.0000
3301	2016-03-24 07:00:00	1	10.7000	72.0000
3302	2016-03-24 07:01:00	1	-3.5000	41.0000
3303	2016-03-24 07:02:00	1	8.1000	43.0000
3304	2016-03-24 07:03:00	1	1.4000	66.0000
3305	2016-03-24 07:04:00	1	-6.7000	74.0000
3306	2016-03-24 07:05:00	1	15.3000	47.0000
3307	2016-03-24 07:06:00	1	22.2000	65.0000
3308	2016-03-24 07:07:00	1	13.3000	43.0000
3309	2016-03-24 07:08:00	1	-8.1000	57.0000
3310	2016-03-24 07:09:00	1	29.1000	40.0000
3311	2016-03-24 07:10:00	1	-5.2000	76.0000
3312	2016-03-24 07:11:00	1	5.6000	78.0000
3313	2016-03-24 07:12:00	1	14.2000	43.0000
3314	2016-03-24 07:13:00	1	25.1000	51.0000
3315	2016-03-24 07:14:00	1	24.3000	40.0000
3316	2016-03-24 07:15:00	1	14.1000	57.0000
3317	2016-03-24 07:16:00	1	-9.0000	59.0000
3318	2016-03-24 07:17:00	1	18.6000	66.0000
3319	2016-03-24 07:18:00	1	8.6000	76.0000
3320	2016-03-24 07:19:00	1	27.5000	50.0000
3321	2016-03-24 07:20:00	1	10.8000	50.0000
3322	2016-03-24 07:21:00	1	0.5000	49.0000
3323	2016-03-24 07:22:00	1	21.6000	75.0000
3324	2016-03-24 07:23:00	1	-2.1000	79.0000
3325	2016-03-24 07:24:00	1	29.7000	53.0000
3326	2016-03-24 07:25:00	1	27.2000	76.0000
3327	2016-03-24 07:26:00	1	-3.7000	73.0000
3328	2016-03-24 07:27:00	1	9.7000	75.0000
3329	2016-03-24 07:28:00	1	-8.1000	73.0000
3330	2016-03-24 07:29:00	1	11.3000	76.0000
3331	2016-03-24 07:30:00	1	1.9000	45.0000
3332	2016-03-24 07:31:00	1	1.2000	65.0000
3333	2016-03-24 07:32:00	1	25.9000	52.0000
3334	2016-03-24 07:33:00	1	22.1000	45.0000
3335	2016-03-24 07:34:00	1	29.8000	63.0000
3336	2016-03-24 07:35:00	1	26.4000	78.0000
3337	2016-03-24 07:36:00	1	2.4000	73.0000
3338	2016-03-24 07:37:00	1	23.6000	48.0000
3339	2016-03-24 07:38:00	1	-9.3000	40.0000
3340	2016-03-24 07:39:00	1	27.5000	40.0000
3341	2016-03-24 07:40:00	1	-1.5000	67.0000
3342	2016-03-24 07:41:00	1	-5.1000	61.0000
3343	2016-03-24 07:42:00	1	-2.5000	70.0000
3344	2016-03-24 07:43:00	1	-4.8000	57.0000
3345	2016-03-24 07:44:00	1	29.4000	43.0000
3346	2016-03-24 07:45:00	1	-4.4000	57.0000
3347	2016-03-24 07:46:00	1	21.8000	66.0000
3348	2016-03-24 07:47:00	1	14.3000	51.0000
3349	2016-03-24 07:48:00	1	6.7000	54.0000
3350	2016-03-24 07:49:00	1	-7.8000	46.0000
3351	2016-03-24 07:50:00	1	-4.0000	72.0000
3352	2016-03-24 07:51:00	1	27.1000	50.0000
3353	2016-03-24 07:52:00	1	-4.6000	71.0000
3354	2016-03-24 07:53:00	1	12.4000	53.0000
3355	2016-03-24 07:54:00	1	22.2000	46.0000
3356	2016-03-24 07:55:00	1	-3.5000	44.0000
3357	2016-03-24 07:56:00	1	4.5000	69.0000
3358	2016-03-24 07:57:00	1	5.4000	54.0000
3359	2016-03-24 07:58:00	1	26.0000	62.0000
3360	2016-03-24 07:59:00	1	21.4000	44.0000
3361	2016-03-24 08:00:00	1	-2.9000	64.0000
3362	2016-03-24 08:01:00	1	-3.3000	52.0000
3363	2016-03-24 08:02:00	1	3.8000	43.0000
3364	2016-03-24 08:03:00	1	16.6000	47.0000
3365	2016-03-24 08:04:00	1	-2.5000	79.0000
3366	2016-03-24 08:05:00	1	-3.0000	53.0000
3367	2016-03-24 08:06:00	1	17.3000	76.0000
3368	2016-03-24 08:07:00	1	21.9000	75.0000
3369	2016-03-24 08:08:00	1	24.8000	61.0000
3370	2016-03-24 08:09:00	1	28.8000	59.0000
3371	2016-03-24 08:10:00	1	24.1000	41.0000
3372	2016-03-24 08:11:00	1	17.7000	41.0000
3373	2016-03-24 08:12:00	1	6.7000	48.0000
3374	2016-03-24 08:13:00	1	20.6000	49.0000
3375	2016-03-24 08:14:00	1	13.7000	66.0000
3376	2016-03-24 08:15:00	1	-1.9000	55.0000
3377	2016-03-24 08:16:00	1	8.9000	73.0000
3378	2016-03-24 08:17:00	1	19.6000	79.0000
3379	2016-03-24 08:18:00	1	-4.2000	50.0000
3380	2016-03-24 08:19:00	1	13.3000	53.0000
3381	2016-03-24 08:20:00	1	-5.0000	79.0000
3382	2016-03-24 08:21:00	1	16.8000	59.0000
3383	2016-03-24 08:22:00	1	24.4000	70.0000
3384	2016-03-24 08:23:00	1	15.1000	43.0000
3385	2016-03-24 08:24:00	1	23.0000	62.0000
3386	2016-03-24 08:25:00	1	6.3000	79.0000
3387	2016-03-24 08:26:00	1	19.1000	44.0000
3388	2016-03-24 08:27:00	1	25.8000	53.0000
3389	2016-03-24 08:28:00	1	-3.0000	75.0000
3390	2016-03-24 08:29:00	1	8.5000	43.0000
3391	2016-03-24 08:30:00	1	-1.7000	75.0000
3392	2016-03-24 08:31:00	1	11.4000	51.0000
3393	2016-03-24 08:32:00	1	-8.7000	65.0000
3394	2016-03-24 08:33:00	1	10.0000	65.0000
3395	2016-03-24 08:34:00	1	17.3000	56.0000
3396	2016-03-24 08:35:00	1	10.4000	43.0000
3397	2016-03-24 08:36:00	1	23.6000	65.0000
3398	2016-03-24 08:37:00	1	14.6000	71.0000
3399	2016-03-24 08:38:00	1	15.9000	57.0000
3400	2016-03-24 08:39:00	1	7.4000	66.0000
3401	2016-03-24 08:40:00	1	23.5000	55.0000
3402	2016-03-24 08:41:00	1	-3.9000	62.0000
3403	2016-03-24 08:42:00	1	27.6000	64.0000
3404	2016-03-24 08:43:00	1	18.4000	72.0000
3405	2016-03-24 08:44:00	1	18.2000	57.0000
3406	2016-03-24 08:45:00	1	25.3000	60.0000
3407	2016-03-24 08:46:00	1	23.4000	54.0000
3408	2016-03-24 08:47:00	1	13.7000	59.0000
3409	2016-03-24 08:48:00	1	17.8000	40.0000
3410	2016-03-24 08:49:00	1	-8.2000	74.0000
3411	2016-03-24 08:50:00	1	-2.9000	62.0000
3412	2016-03-24 08:51:00	1	-2.7000	72.0000
3413	2016-03-24 08:52:00	1	19.3000	59.0000
3414	2016-03-24 08:53:00	1	18.8000	62.0000
3415	2016-03-24 08:54:00	1	-8.5000	57.0000
3416	2016-03-24 08:55:00	1	24.2000	76.0000
3417	2016-03-24 08:56:00	1	29.9000	72.0000
3418	2016-03-24 08:57:00	1	7.7000	52.0000
3419	2016-03-24 08:58:00	1	-7.8000	73.0000
3420	2016-03-24 08:59:00	1	-7.9000	55.0000
3421	2016-03-24 09:00:00	1	3.0000	60.0000
3422	2016-03-24 09:01:00	1	16.9000	41.0000
3423	2016-03-24 09:02:00	1	4.2000	45.0000
3424	2016-03-24 09:03:00	1	-8.9000	52.0000
3425	2016-03-24 09:04:00	1	4.4000	44.0000
3426	2016-03-24 09:05:00	1	7.0000	62.0000
3427	2016-03-24 09:06:00	1	15.0000	42.0000
3428	2016-03-24 09:07:00	1	12.2000	53.0000
3429	2016-03-24 09:08:00	1	6.2000	57.0000
3430	2016-03-24 09:09:00	1	19.5000	58.0000
3431	2016-03-24 09:10:00	1	7.2000	62.0000
3432	2016-03-24 09:11:00	1	2.8000	46.0000
3433	2016-03-24 09:12:00	1	14.1000	71.0000
3434	2016-03-24 09:13:00	1	4.6000	51.0000
3435	2016-03-24 09:14:00	1	26.6000	42.0000
3436	2016-03-24 09:15:00	1	6.8000	53.0000
3437	2016-03-24 09:16:00	1	4.2000	40.0000
3438	2016-03-24 09:17:00	1	6.0000	55.0000
3439	2016-03-24 09:18:00	1	4.4000	54.0000
3440	2016-03-24 09:19:00	1	20.4000	51.0000
3441	2016-03-24 09:20:00	1	9.9000	53.0000
3442	2016-03-24 09:21:00	1	0.3000	64.0000
3443	2016-03-24 09:22:00	1	21.7000	67.0000
3444	2016-03-24 09:23:00	1	9.2000	57.0000
3445	2016-03-24 09:24:00	1	-6.4000	53.0000
3446	2016-03-24 09:25:00	1	15.6000	78.0000
3447	2016-03-24 09:26:00	1	22.5000	68.0000
3448	2016-03-24 09:27:00	1	28.0000	50.0000
3449	2016-03-24 09:28:00	1	18.8000	61.0000
3450	2016-03-24 09:29:00	1	-7.0000	43.0000
3451	2016-03-24 09:30:00	1	19.3000	66.0000
3452	2016-03-24 09:31:00	1	25.0000	44.0000
3453	2016-03-24 09:32:00	1	13.5000	49.0000
3454	2016-03-24 09:33:00	1	22.0000	72.0000
3455	2016-03-24 09:34:00	1	18.1000	66.0000
3456	2016-03-24 09:35:00	1	16.7000	61.0000
3457	2016-03-24 09:36:00	1	19.8000	56.0000
3458	2016-03-24 09:37:00	1	2.9000	74.0000
3459	2016-03-24 09:38:00	1	19.6000	43.0000
3460	2016-03-24 09:39:00	1	19.4000	67.0000
3461	2016-03-24 09:40:00	1	-9.3000	66.0000
3462	2016-03-24 09:41:00	1	4.1000	51.0000
3463	2016-03-24 09:42:00	1	3.5000	69.0000
3464	2016-03-24 09:43:00	1	-0.1000	72.0000
3465	2016-03-24 09:44:00	1	14.6000	41.0000
3466	2016-03-24 09:45:00	1	17.7000	53.0000
3467	2016-03-24 09:46:00	1	22.6000	50.0000
3468	2016-03-24 09:47:00	1	7.5000	74.0000
3469	2016-03-24 09:48:00	1	23.8000	57.0000
3470	2016-03-24 09:49:00	1	4.0000	42.0000
3471	2016-03-24 09:50:00	1	21.8000	68.0000
3472	2016-03-24 09:51:00	1	20.0000	62.0000
3473	2016-03-24 09:52:00	1	27.7000	68.0000
3474	2016-03-24 09:53:00	1	-6.9000	47.0000
3475	2016-03-24 09:54:00	1	24.9000	67.0000
3476	2016-03-24 09:55:00	1	10.5000	48.0000
3477	2016-03-24 09:56:00	1	-2.3000	59.0000
3478	2016-03-24 09:57:00	1	18.9000	46.0000
3479	2016-03-24 09:58:00	1	-3.3000	40.0000
3480	2016-03-24 09:59:00	1	13.4000	79.0000
3481	2016-03-24 10:00:00	1	1.5000	53.0000
3482	2016-03-24 10:01:00	1	-4.7000	68.0000
3483	2016-03-24 10:02:00	1	23.9000	70.0000
3484	2016-03-24 10:03:00	1	10.2000	43.0000
3485	2016-03-24 10:04:00	1	22.2000	47.0000
3486	2016-03-24 10:05:00	1	-0.3000	70.0000
3487	2016-03-24 10:06:00	1	24.8000	48.0000
3488	2016-03-24 10:07:00	1	-4.4000	59.0000
3489	2016-03-24 10:08:00	1	-7.5000	49.0000
3490	2016-03-24 10:09:00	1	9.8000	48.0000
3491	2016-03-24 10:10:00	1	-8.7000	60.0000
3492	2016-03-24 10:11:00	1	23.0000	69.0000
3493	2016-03-24 10:12:00	1	25.0000	74.0000
3494	2016-03-24 10:13:00	1	20.0000	48.0000
3495	2016-03-24 10:14:00	1	10.6000	53.0000
3496	2016-03-24 10:15:00	1	23.1000	75.0000
3497	2016-03-24 10:16:00	1	14.6000	40.0000
3498	2016-03-24 10:17:00	1	26.3000	50.0000
3499	2016-03-24 10:18:00	1	11.1000	46.0000
3500	2016-03-24 10:19:00	1	-3.7000	57.0000
3501	2016-03-24 10:20:00	1	0.7000	58.0000
3502	2016-03-24 10:21:00	1	27.2000	69.0000
3503	2016-03-24 10:22:00	1	5.6000	40.0000
3504	2016-03-24 10:23:00	1	28.0000	42.0000
3505	2016-03-24 10:24:00	1	1.4000	54.0000
3506	2016-03-24 10:25:00	1	5.5000	45.0000
3507	2016-03-24 10:26:00	1	8.3000	65.0000
3508	2016-03-24 10:27:00	1	11.7000	73.0000
3509	2016-03-24 10:28:00	1	20.5000	69.0000
3510	2016-03-24 10:29:00	1	5.0000	53.0000
3511	2016-03-24 10:30:00	1	15.2000	49.0000
3512	2016-03-24 10:31:00	1	-6.7000	69.0000
3513	2016-03-24 10:32:00	1	-3.6000	72.0000
3514	2016-03-24 10:33:00	1	18.3000	59.0000
3515	2016-03-24 10:34:00	1	6.1000	71.0000
3516	2016-03-24 10:35:00	1	-9.3000	71.0000
3517	2016-03-24 10:36:00	1	0.6000	64.0000
3518	2016-03-24 10:37:00	1	22.3000	55.0000
3519	2016-03-24 10:38:00	1	-9.4000	47.0000
3520	2016-03-24 10:39:00	1	-5.7000	73.0000
3521	2016-03-24 10:40:00	1	-1.8000	66.0000
3522	2016-03-24 10:41:00	1	14.7000	75.0000
3523	2016-03-24 10:42:00	1	18.4000	53.0000
3524	2016-03-24 10:43:00	1	29.7000	70.0000
3525	2016-03-24 10:44:00	1	8.1000	49.0000
3526	2016-03-24 10:45:00	1	20.0000	44.0000
3527	2016-03-24 10:46:00	1	12.8000	71.0000
3528	2016-03-24 10:47:00	1	3.1000	67.0000
3529	2016-03-24 10:48:00	1	22.9000	52.0000
3530	2016-03-24 10:49:00	1	6.5000	41.0000
3531	2016-03-24 10:50:00	1	25.9000	42.0000
3532	2016-03-24 10:51:00	1	25.8000	53.0000
3533	2016-03-24 10:52:00	1	5.0000	71.0000
3534	2016-03-24 10:53:00	1	22.7000	50.0000
3535	2016-03-24 10:54:00	1	8.4000	64.0000
3536	2016-03-24 10:55:00	1	17.6000	79.0000
3537	2016-03-24 10:56:00	1	6.9000	61.0000
3538	2016-03-24 10:57:00	1	3.1000	61.0000
3539	2016-03-24 10:58:00	1	8.8000	61.0000
3540	2016-03-24 10:59:00	1	14.2000	76.0000
3541	2016-03-24 11:00:00	1	17.6000	53.0000
3542	2016-03-24 11:01:00	1	-9.8000	49.0000
3543	2016-03-24 11:02:00	1	-2.4000	73.0000
3544	2016-03-24 11:03:00	1	29.5000	48.0000
3545	2016-03-24 11:04:00	1	4.6000	42.0000
3546	2016-03-24 11:05:00	1	-0.5000	49.0000
3547	2016-03-24 11:06:00	1	23.2000	41.0000
3548	2016-03-24 11:07:00	1	7.1000	69.0000
3549	2016-03-24 11:08:00	1	23.5000	69.0000
3550	2016-03-24 11:09:00	1	13.8000	69.0000
3551	2016-03-24 11:10:00	1	-3.2000	41.0000
3552	2016-03-24 11:11:00	1	28.6000	42.0000
3553	2016-03-24 11:12:00	1	13.8000	41.0000
3554	2016-03-24 11:13:00	1	19.0000	56.0000
3555	2016-03-24 11:14:00	1	14.6000	53.0000
3556	2016-03-24 11:15:00	1	29.4000	73.0000
3557	2016-03-24 11:16:00	1	17.5000	52.0000
3558	2016-03-24 11:17:00	1	12.5000	72.0000
3559	2016-03-24 11:18:00	1	2.9000	58.0000
3560	2016-03-24 11:19:00	1	25.6000	71.0000
3561	2016-03-24 11:20:00	1	28.0000	49.0000
3562	2016-03-24 11:21:00	1	28.2000	63.0000
3563	2016-03-24 11:22:00	1	0.5000	42.0000
3564	2016-03-24 11:23:00	1	29.4000	60.0000
3565	2016-03-24 11:24:00	1	15.0000	50.0000
3566	2016-03-24 11:25:00	1	5.8000	43.0000
3567	2016-03-24 11:26:00	1	24.6000	57.0000
3568	2016-03-24 11:27:00	1	5.5000	74.0000
3569	2016-03-24 11:28:00	1	16.1000	48.0000
3570	2016-03-24 11:29:00	1	10.9000	41.0000
3571	2016-03-24 11:30:00	1	7.7000	42.0000
3572	2016-03-24 11:31:00	1	12.9000	69.0000
3573	2016-03-24 11:32:00	1	10.0000	57.0000
3574	2016-03-24 11:33:00	1	-9.8000	79.0000
3575	2016-03-24 11:34:00	1	17.4000	40.0000
3576	2016-03-24 11:35:00	1	10.5000	55.0000
3577	2016-03-24 11:36:00	1	-9.1000	70.0000
3578	2016-03-24 11:37:00	1	6.6000	77.0000
3579	2016-03-24 11:38:00	1	23.9000	70.0000
3580	2016-03-24 11:39:00	1	5.4000	62.0000
3581	2016-03-24 11:40:00	1	29.2000	47.0000
3582	2016-03-24 11:41:00	1	0.7000	51.0000
3583	2016-03-24 11:42:00	1	-4.4000	51.0000
3584	2016-03-24 11:43:00	1	2.2000	63.0000
3585	2016-03-24 11:44:00	1	20.6000	55.0000
3586	2016-03-24 11:45:00	1	-7.6000	41.0000
3587	2016-03-24 11:46:00	1	3.5000	59.0000
3588	2016-03-24 11:47:00	1	3.5000	51.0000
3589	2016-03-24 11:48:00	1	20.7000	69.0000
3590	2016-03-24 11:49:00	1	16.5000	70.0000
3591	2016-03-24 11:50:00	1	-0.4000	41.0000
3592	2016-03-24 11:51:00	1	-6.6000	57.0000
3593	2016-03-24 11:52:00	1	15.7000	62.0000
3594	2016-03-24 11:53:00	1	11.9000	62.0000
3595	2016-03-24 11:54:00	1	26.0000	52.0000
3596	2016-03-24 11:55:00	1	28.6000	52.0000
3597	2016-03-24 11:56:00	1	18.5000	69.0000
3598	2016-03-24 11:57:00	1	19.0000	43.0000
3599	2016-03-24 11:58:00	1	25.5000	68.0000
3600	2016-03-24 11:59:00	1	15.8000	79.0000
3601	2016-03-24 12:00:00	1	24.3000	51.0000
3602	2016-03-24 12:01:00	1	24.5000	41.0000
3603	2016-03-24 12:02:00	1	3.5000	69.0000
3604	2016-03-24 12:03:00	1	-8.6000	44.0000
3605	2016-03-24 12:04:00	1	11.7000	43.0000
3606	2016-03-24 12:05:00	1	12.3000	47.0000
3607	2016-03-24 12:06:00	1	24.9000	59.0000
3608	2016-03-24 12:07:00	1	-8.2000	54.0000
3609	2016-03-24 12:08:00	1	-4.3000	58.0000
3610	2016-03-24 12:09:00	1	-9.7000	72.0000
3611	2016-03-24 12:10:00	1	11.0000	60.0000
3612	2016-03-24 12:11:00	1	26.8000	49.0000
3613	2016-03-24 12:12:00	1	-1.8000	47.0000
3614	2016-03-24 12:13:00	1	-6.4000	68.0000
3615	2016-03-24 12:14:00	1	17.0000	59.0000
3616	2016-03-24 12:15:00	1	19.9000	58.0000
3617	2016-03-24 12:16:00	1	7.7000	46.0000
3618	2016-03-24 12:17:00	1	19.1000	79.0000
3619	2016-03-24 12:18:00	1	22.4000	51.0000
3620	2016-03-24 12:19:00	1	25.5000	53.0000
3621	2016-03-24 12:20:00	1	8.4000	78.0000
3622	2016-03-24 12:21:00	1	-4.6000	57.0000
3623	2016-03-24 12:22:00	1	-6.5000	45.0000
3624	2016-03-24 12:23:00	1	23.9000	57.0000
3625	2016-03-24 12:24:00	1	20.9000	47.0000
3626	2016-03-24 12:25:00	1	0.9000	73.0000
3627	2016-03-24 12:26:00	1	23.1000	53.0000
3628	2016-03-24 12:27:00	1	11.4000	56.0000
3629	2016-03-24 12:28:00	1	23.5000	54.0000
3630	2016-03-24 12:29:00	1	-4.9000	74.0000
3631	2016-03-24 12:30:00	1	4.4000	52.0000
3632	2016-03-24 12:31:00	1	-8.3000	43.0000
3633	2016-03-24 12:32:00	1	9.5000	71.0000
3634	2016-03-24 12:33:00	1	13.3000	53.0000
3635	2016-03-24 12:34:00	1	11.4000	46.0000
3636	2016-03-24 12:35:00	1	16.0000	56.0000
3637	2016-03-24 12:36:00	1	26.5000	47.0000
3638	2016-03-24 12:37:00	1	3.1000	60.0000
3639	2016-03-24 12:38:00	1	28.6000	65.0000
3640	2016-03-24 12:39:00	1	-0.8000	75.0000
3641	2016-03-24 12:40:00	1	-8.8000	46.0000
3642	2016-03-24 12:41:00	1	-8.7000	59.0000
3643	2016-03-24 12:42:00	1	17.8000	70.0000
3644	2016-03-24 12:43:00	1	25.6000	58.0000
3645	2016-03-24 12:44:00	1	-2.3000	60.0000
3646	2016-03-24 12:45:00	1	-8.3000	78.0000
3647	2016-03-24 12:46:00	1	25.8000	44.0000
3648	2016-03-24 12:47:00	1	4.1000	50.0000
3649	2016-03-24 12:48:00	1	24.3000	44.0000
3650	2016-03-24 12:49:00	1	17.1000	58.0000
3651	2016-03-24 12:50:00	1	6.1000	49.0000
3652	2016-03-24 12:51:00	1	5.4000	73.0000
3653	2016-03-24 12:52:00	1	-5.4000	47.0000
3654	2016-03-24 12:53:00	1	2.6000	68.0000
3655	2016-03-24 12:54:00	1	25.4000	70.0000
3656	2016-03-24 12:55:00	1	22.6000	64.0000
3657	2016-03-24 12:56:00	1	-8.1000	51.0000
3658	2016-03-24 12:57:00	1	20.9000	75.0000
3659	2016-03-24 12:58:00	1	6.7000	79.0000
3660	2016-03-24 12:59:00	1	0.9000	66.0000
3661	2016-03-24 13:00:00	1	17.2000	45.0000
3662	2016-03-24 13:01:00	1	-3.6000	50.0000
3663	2016-03-24 13:02:00	1	6.0000	46.0000
3664	2016-03-24 13:03:00	1	28.3000	45.0000
3665	2016-03-24 13:04:00	1	7.8000	43.0000
3666	2016-03-24 13:05:00	1	16.0000	79.0000
3667	2016-03-24 13:06:00	1	28.6000	56.0000
3668	2016-03-24 13:07:00	1	-3.4000	48.0000
3669	2016-03-24 13:08:00	1	19.9000	66.0000
3670	2016-03-24 13:09:00	1	-3.7000	75.0000
3671	2016-03-24 13:10:00	1	-9.0000	60.0000
3672	2016-03-24 13:11:00	1	11.9000	52.0000
3673	2016-03-24 13:12:00	1	22.8000	41.0000
3674	2016-03-24 13:13:00	1	22.5000	73.0000
3675	2016-03-24 13:14:00	1	29.3000	60.0000
3676	2016-03-24 13:15:00	1	23.8000	79.0000
3677	2016-03-24 13:16:00	1	6.0000	44.0000
3678	2016-03-24 13:17:00	1	-0.4000	75.0000
3679	2016-03-24 13:18:00	1	10.6000	49.0000
3680	2016-03-24 13:19:00	1	-7.6000	40.0000
3681	2016-03-24 13:20:00	1	23.3000	43.0000
3682	2016-03-24 13:21:00	1	22.4000	63.0000
3683	2016-03-24 13:22:00	1	19.7000	52.0000
3684	2016-03-24 13:23:00	1	25.0000	42.0000
3685	2016-03-24 13:24:00	1	8.1000	68.0000
3686	2016-03-24 13:25:00	1	-5.1000	74.0000
3687	2016-03-24 13:26:00	1	-9.8000	75.0000
3688	2016-03-24 13:27:00	1	11.9000	59.0000
3689	2016-03-24 13:28:00	1	29.6000	53.0000
3690	2016-03-24 13:29:00	1	-7.5000	76.0000
3691	2016-03-24 13:30:00	1	7.8000	52.0000
3692	2016-03-24 13:31:00	1	15.5000	59.0000
3693	2016-03-24 13:32:00	1	26.5000	64.0000
3694	2016-03-24 13:33:00	1	15.8000	46.0000
3695	2016-03-24 13:34:00	1	-7.0000	55.0000
3696	2016-03-24 13:35:00	1	5.6000	64.0000
3697	2016-03-24 13:36:00	1	6.6000	45.0000
3698	2016-03-24 13:37:00	1	18.2000	57.0000
3699	2016-03-24 13:38:00	1	-3.0000	58.0000
3700	2016-03-24 13:39:00	1	15.9000	55.0000
3701	2016-03-24 13:40:00	1	14.5000	75.0000
3702	2016-03-24 13:41:00	1	-5.7000	54.0000
3703	2016-03-24 13:42:00	1	7.5000	55.0000
3704	2016-03-24 13:43:00	1	7.8000	66.0000
3705	2016-03-24 13:44:00	1	-9.4000	66.0000
3706	2016-03-24 13:45:00	1	6.0000	42.0000
3707	2016-03-24 13:46:00	1	6.7000	56.0000
3708	2016-03-24 13:47:00	1	2.3000	73.0000
3709	2016-03-24 13:48:00	1	26.6000	56.0000
3710	2016-03-24 13:49:00	1	20.4000	52.0000
3711	2016-03-24 13:50:00	1	16.3000	45.0000
3712	2016-03-24 13:51:00	1	25.8000	68.0000
3713	2016-03-24 13:52:00	1	4.1000	62.0000
3714	2016-03-24 13:53:00	1	-0.8000	66.0000
3715	2016-03-24 13:54:00	1	-2.9000	44.0000
3716	2016-03-24 13:55:00	1	-3.8000	47.0000
3717	2016-03-24 13:56:00	1	15.8000	49.0000
3718	2016-03-24 13:57:00	1	6.4000	68.0000
3719	2016-03-24 13:58:00	1	26.7000	55.0000
3720	2016-03-24 13:59:00	1	10.4000	52.0000
3721	2016-03-24 14:00:00	1	4.5000	76.0000
3722	2016-03-24 14:01:00	1	5.8000	59.0000
3723	2016-03-24 14:02:00	1	27.8000	55.0000
3724	2016-03-24 14:03:00	1	-5.5000	51.0000
3725	2016-03-24 14:04:00	1	16.2000	51.0000
3726	2016-03-24 14:05:00	1	23.9000	61.0000
3727	2016-03-24 14:06:00	1	-9.0000	79.0000
3728	2016-03-24 14:07:00	1	5.4000	66.0000
3729	2016-03-24 14:08:00	1	3.6000	54.0000
3730	2016-03-24 14:09:00	1	26.1000	42.0000
3731	2016-03-24 14:10:00	1	9.6000	72.0000
3732	2016-03-24 14:11:00	1	2.4000	57.0000
3733	2016-03-24 14:12:00	1	2.8000	51.0000
3734	2016-03-24 14:13:00	1	-1.4000	45.0000
3735	2016-03-24 14:14:00	1	13.0000	79.0000
3736	2016-03-24 14:15:00	1	-3.2000	48.0000
3737	2016-03-24 14:16:00	1	15.4000	70.0000
3738	2016-03-24 14:17:00	1	18.8000	46.0000
3739	2016-03-24 14:18:00	1	0.6000	59.0000
3740	2016-03-24 14:19:00	1	7.6000	56.0000
3741	2016-03-24 14:20:00	1	18.2000	41.0000
3742	2016-03-24 14:21:00	1	-0.7000	47.0000
3743	2016-03-24 14:22:00	1	-8.8000	46.0000
3744	2016-03-24 14:23:00	1	-5.8000	41.0000
3745	2016-03-24 14:24:00	1	-0.8000	64.0000
3746	2016-03-24 14:25:00	1	25.6000	59.0000
3747	2016-03-24 14:26:00	1	-7.5000	53.0000
3748	2016-03-24 14:27:00	1	24.1000	78.0000
3749	2016-03-24 14:28:00	1	26.7000	40.0000
3750	2016-03-24 14:29:00	1	14.8000	50.0000
3751	2016-03-24 14:30:00	1	21.8000	59.0000
3752	2016-03-24 14:31:00	1	7.2000	74.0000
3753	2016-03-24 14:32:00	1	4.2000	65.0000
3754	2016-03-24 14:33:00	1	-9.6000	54.0000
3755	2016-03-24 14:34:00	1	29.3000	78.0000
3756	2016-03-24 14:35:00	1	11.6000	75.0000
3757	2016-03-24 14:36:00	1	19.5000	47.0000
3758	2016-03-24 14:37:00	1	6.6000	59.0000
3759	2016-03-24 14:38:00	1	5.6000	74.0000
3760	2016-03-24 14:39:00	1	-4.4000	54.0000
3761	2016-03-24 14:40:00	1	11.0000	44.0000
3762	2016-03-24 14:41:00	1	3.6000	54.0000
3763	2016-03-24 14:42:00	1	-0.9000	69.0000
3764	2016-03-24 14:43:00	1	28.9000	41.0000
3765	2016-03-24 14:44:00	1	0.5000	54.0000
3766	2016-03-24 14:45:00	1	15.6000	68.0000
3767	2016-03-24 14:46:00	1	5.3000	48.0000
3768	2016-03-24 14:47:00	1	9.5000	63.0000
3769	2016-03-24 14:48:00	1	-1.2000	42.0000
3770	2016-03-24 14:49:00	1	4.2000	57.0000
3771	2016-03-24 14:50:00	1	27.8000	48.0000
3772	2016-03-24 14:51:00	1	25.5000	59.0000
3773	2016-03-24 14:52:00	1	16.8000	53.0000
3774	2016-03-24 14:53:00	1	8.0000	48.0000
3775	2016-03-24 14:54:00	1	22.9000	58.0000
3776	2016-03-24 14:55:00	1	17.2000	45.0000
3777	2016-03-24 14:56:00	1	14.8000	76.0000
3778	2016-03-24 14:57:00	1	27.4000	59.0000
3779	2016-03-24 14:58:00	1	-1.4000	52.0000
3780	2016-03-24 14:59:00	1	29.7000	54.0000
3781	2016-03-24 15:00:00	1	9.9000	51.0000
3782	2016-03-24 15:01:00	1	11.4000	60.0000
3783	2016-03-24 15:02:00	1	18.1000	44.0000
3784	2016-03-24 15:03:00	1	14.6000	52.0000
3785	2016-03-24 15:04:00	1	10.7000	60.0000
3786	2016-03-24 15:05:00	1	-5.0000	46.0000
3787	2016-03-24 15:06:00	1	24.8000	40.0000
3788	2016-03-24 15:07:00	1	-4.2000	42.0000
3789	2016-03-24 15:08:00	1	2.7000	62.0000
3790	2016-03-24 15:09:00	1	13.9000	41.0000
3791	2016-03-24 15:10:00	1	-2.6000	53.0000
3792	2016-03-24 15:11:00	1	9.4000	63.0000
3793	2016-03-24 15:12:00	1	1.9000	46.0000
3794	2016-03-24 15:13:00	1	16.1000	74.0000
3795	2016-03-24 15:14:00	1	3.1000	43.0000
3796	2016-03-24 15:15:00	1	29.5000	43.0000
3797	2016-03-24 15:16:00	1	1.1000	70.0000
3798	2016-03-24 15:17:00	1	18.2000	52.0000
3799	2016-03-24 15:18:00	1	11.8000	65.0000
3800	2016-03-24 15:19:00	1	26.2000	40.0000
3801	2016-03-24 15:20:00	1	1.8000	52.0000
3802	2016-03-24 15:21:00	1	11.0000	53.0000
3803	2016-03-24 15:22:00	1	-8.3000	51.0000
3804	2016-03-24 15:23:00	1	18.1000	45.0000
3805	2016-03-24 15:24:00	1	0.6000	45.0000
3806	2016-03-24 15:25:00	1	9.9000	74.0000
3807	2016-03-24 15:26:00	1	13.1000	52.0000
3808	2016-03-24 15:27:00	1	0.2000	47.0000
3809	2016-03-24 15:28:00	1	6.1000	60.0000
3810	2016-03-24 15:29:00	1	5.4000	55.0000
3811	2016-03-24 15:30:00	1	12.1000	69.0000
3812	2016-03-24 15:31:00	1	12.3000	55.0000
3813	2016-03-24 15:32:00	1	25.9000	61.0000
3814	2016-03-24 15:33:00	1	22.5000	54.0000
3815	2016-03-24 15:34:00	1	13.4000	51.0000
3816	2016-03-24 15:35:00	1	10.3000	72.0000
3817	2016-03-24 15:36:00	1	19.9000	60.0000
3818	2016-03-24 15:37:00	1	-8.3000	55.0000
3819	2016-03-24 15:38:00	1	18.1000	59.0000
3820	2016-03-24 15:39:00	1	-4.0000	44.0000
3821	2016-03-24 15:40:00	1	-8.2000	67.0000
3822	2016-03-24 15:41:00	1	6.8000	62.0000
3823	2016-03-24 15:42:00	1	15.2000	75.0000
3824	2016-03-24 15:43:00	1	9.8000	56.0000
3825	2016-03-24 15:44:00	1	13.3000	52.0000
3826	2016-03-24 15:45:00	1	20.5000	57.0000
3827	2016-03-24 15:46:00	1	0.1000	69.0000
3828	2016-03-24 15:47:00	1	28.6000	61.0000
3829	2016-03-24 15:48:00	1	13.3000	79.0000
3830	2016-03-24 15:49:00	1	13.8000	57.0000
3831	2016-03-24 15:50:00	1	9.8000	68.0000
3832	2016-03-24 15:51:00	1	-8.1000	73.0000
3833	2016-03-24 15:52:00	1	-4.6000	52.0000
3834	2016-03-24 15:53:00	1	-8.7000	59.0000
3835	2016-03-24 15:54:00	1	23.4000	69.0000
3836	2016-03-24 15:55:00	1	22.3000	76.0000
3837	2016-03-24 15:56:00	1	23.2000	61.0000
3838	2016-03-24 15:57:00	1	9.9000	74.0000
3839	2016-03-24 15:58:00	1	26.2000	68.0000
3840	2016-03-24 15:59:00	1	9.7000	50.0000
3841	2016-03-24 16:00:00	1	24.9000	41.0000
3842	2016-03-24 16:01:00	1	14.9000	40.0000
3843	2016-03-24 16:02:00	1	13.0000	78.0000
3844	2016-03-24 16:03:00	1	1.0000	61.0000
3845	2016-03-24 16:04:00	1	4.6000	75.0000
3846	2016-03-24 16:05:00	1	3.0000	67.0000
3847	2016-03-24 16:06:00	1	28.9000	45.0000
3848	2016-03-24 16:07:00	1	-6.0000	72.0000
3849	2016-03-24 16:08:00	1	8.5000	69.0000
3850	2016-03-24 16:09:00	1	27.9000	49.0000
3851	2016-03-24 16:10:00	1	2.5000	55.0000
3852	2016-03-24 16:11:00	1	-3.0000	53.0000
3853	2016-03-24 16:12:00	1	29.4000	43.0000
3854	2016-03-24 16:13:00	1	14.0000	72.0000
3855	2016-03-24 16:14:00	1	16.6000	56.0000
3856	2016-03-24 16:15:00	1	5.0000	50.0000
3857	2016-03-24 16:16:00	1	4.0000	48.0000
3858	2016-03-24 16:17:00	1	16.5000	48.0000
3859	2016-03-24 16:18:00	1	13.4000	72.0000
3860	2016-03-24 16:19:00	1	-6.7000	44.0000
3861	2016-03-24 16:20:00	1	22.3000	66.0000
3862	2016-03-24 16:21:00	1	22.3000	51.0000
3863	2016-03-24 16:22:00	1	21.3000	72.0000
3864	2016-03-24 16:23:00	1	25.5000	49.0000
3865	2016-03-24 16:24:00	1	-8.4000	75.0000
3866	2016-03-24 16:25:00	1	11.6000	57.0000
3867	2016-03-24 16:26:00	1	13.6000	43.0000
3868	2016-03-24 16:27:00	1	9.8000	46.0000
3869	2016-03-24 16:28:00	1	5.5000	56.0000
3870	2016-03-24 16:29:00	1	8.5000	76.0000
3871	2016-03-24 16:30:00	1	-2.5000	79.0000
3872	2016-03-24 16:31:00	1	13.6000	70.0000
3873	2016-03-24 16:32:00	1	23.4000	57.0000
3874	2016-03-24 16:33:00	1	8.5000	74.0000
3875	2016-03-24 16:34:00	1	-2.5000	46.0000
3876	2016-03-24 16:35:00	1	4.7000	76.0000
3877	2016-03-24 16:36:00	1	28.2000	49.0000
3878	2016-03-24 16:37:00	1	21.0000	43.0000
3879	2016-03-24 16:38:00	1	-6.7000	71.0000
3880	2016-03-24 16:39:00	1	29.2000	60.0000
3881	2016-03-24 16:40:00	1	9.9000	50.0000
3882	2016-03-24 16:41:00	1	8.9000	56.0000
3883	2016-03-24 16:42:00	1	-0.7000	48.0000
3884	2016-03-24 16:43:00	1	16.5000	58.0000
3885	2016-03-24 16:44:00	1	-7.5000	60.0000
3886	2016-03-24 16:45:00	1	16.8000	77.0000
3887	2016-03-24 16:46:00	1	28.5000	41.0000
3888	2016-03-24 16:47:00	1	21.5000	47.0000
3889	2016-03-24 16:48:00	1	10.4000	65.0000
3890	2016-03-24 16:49:00	1	-1.4000	67.0000
3891	2016-03-24 16:50:00	1	21.8000	58.0000
3892	2016-03-24 16:51:00	1	17.8000	43.0000
3893	2016-03-24 16:52:00	1	20.3000	50.0000
3894	2016-03-24 16:53:00	1	9.4000	47.0000
3895	2016-03-24 16:54:00	1	-4.7000	58.0000
3896	2016-03-24 16:55:00	1	28.5000	47.0000
3897	2016-03-24 16:56:00	1	29.3000	46.0000
3898	2016-03-24 16:57:00	1	18.7000	41.0000
3899	2016-03-24 16:58:00	1	6.2000	66.0000
3900	2016-03-24 16:59:00	1	23.4000	78.0000
3901	2016-03-24 17:00:00	1	10.1000	74.0000
3902	2016-03-24 17:01:00	1	18.7000	46.0000
3903	2016-03-24 17:02:00	1	20.6000	62.0000
3904	2016-03-24 17:03:00	1	0.5000	53.0000
3905	2016-03-24 17:04:00	1	20.1000	54.0000
3906	2016-03-24 17:05:00	1	29.0000	58.0000
3907	2016-03-24 17:06:00	1	-7.6000	43.0000
3908	2016-03-24 17:07:00	1	1.8000	79.0000
3909	2016-03-24 17:08:00	1	-4.4000	67.0000
3910	2016-03-24 17:09:00	1	16.4000	53.0000
3911	2016-03-24 17:10:00	1	-0.3000	74.0000
3912	2016-03-24 17:11:00	1	26.1000	73.0000
3913	2016-03-24 17:12:00	1	-7.6000	42.0000
3914	2016-03-24 17:13:00	1	7.6000	54.0000
3915	2016-03-24 17:14:00	1	29.9000	53.0000
3916	2016-03-24 17:15:00	1	27.2000	54.0000
3917	2016-03-24 17:16:00	1	21.1000	47.0000
3918	2016-03-24 17:17:00	1	28.6000	42.0000
3919	2016-03-24 17:18:00	1	-4.0000	73.0000
3920	2016-03-24 17:19:00	1	22.8000	56.0000
3921	2016-03-24 17:20:00	1	18.2000	55.0000
3922	2016-03-24 17:21:00	1	8.0000	59.0000
3923	2016-03-24 17:22:00	1	8.6000	55.0000
3924	2016-03-24 17:23:00	1	13.4000	50.0000
3925	2016-03-24 17:24:00	1	11.0000	65.0000
3926	2016-03-24 17:25:00	1	25.1000	67.0000
3927	2016-03-24 17:26:00	1	24.8000	63.0000
3928	2016-03-24 17:27:00	1	29.7000	60.0000
3929	2016-03-24 17:28:00	1	6.0000	74.0000
3930	2016-03-24 17:29:00	1	5.7000	54.0000
3931	2016-03-24 17:30:00	1	18.2000	65.0000
3932	2016-03-24 17:31:00	1	26.0000	74.0000
3933	2016-03-24 17:32:00	1	28.7000	67.0000
3934	2016-03-24 17:33:00	1	-8.9000	40.0000
3935	2016-03-24 17:34:00	1	-6.4000	51.0000
3936	2016-03-24 17:35:00	1	-9.2000	67.0000
3937	2016-03-24 17:36:00	1	15.7000	50.0000
3938	2016-03-24 17:37:00	1	12.5000	44.0000
3939	2016-03-24 17:38:00	1	-1.4000	65.0000
3940	2016-03-24 17:39:00	1	18.5000	67.0000
3941	2016-03-24 17:40:00	1	5.7000	78.0000
3942	2016-03-24 17:41:00	1	10.3000	69.0000
3943	2016-03-24 17:42:00	1	4.8000	54.0000
3944	2016-03-24 17:43:00	1	-2.3000	47.0000
3945	2016-03-24 17:44:00	1	27.2000	62.0000
3946	2016-03-24 17:45:00	1	-3.3000	75.0000
3947	2016-03-24 17:46:00	1	26.3000	48.0000
3948	2016-03-24 17:47:00	1	-5.3000	60.0000
3949	2016-03-24 17:48:00	1	27.2000	45.0000
3950	2016-03-24 17:49:00	1	29.8000	56.0000
3951	2016-03-24 17:50:00	1	29.7000	56.0000
3952	2016-03-24 17:51:00	1	22.7000	63.0000
3953	2016-03-24 17:52:00	1	9.5000	70.0000
3954	2016-03-24 17:53:00	1	19.7000	71.0000
3955	2016-03-24 17:54:00	1	11.0000	42.0000
3956	2016-03-24 17:55:00	1	7.7000	64.0000
3957	2016-03-24 17:56:00	1	-8.2000	52.0000
3958	2016-03-24 17:57:00	1	-2.7000	62.0000
3959	2016-03-24 17:58:00	1	8.0000	41.0000
3960	2016-03-24 17:59:00	1	-2.5000	74.0000
3961	2016-03-24 18:00:00	1	28.4000	49.0000
3962	2016-03-24 18:01:00	1	-9.3000	51.0000
3963	2016-03-24 18:02:00	1	6.9000	77.0000
3964	2016-03-24 18:03:00	1	19.8000	53.0000
3965	2016-03-24 18:04:00	1	1.2000	51.0000
3966	2016-03-24 18:05:00	1	5.0000	77.0000
3967	2016-03-24 18:06:00	1	20.2000	53.0000
3968	2016-03-24 18:07:00	1	26.3000	53.0000
3969	2016-03-24 18:08:00	1	12.8000	67.0000
3970	2016-03-24 18:09:00	1	27.7000	56.0000
3971	2016-03-24 18:10:00	1	-5.7000	42.0000
3972	2016-03-24 18:11:00	1	-9.4000	49.0000
3973	2016-03-24 18:12:00	1	3.5000	53.0000
3974	2016-03-24 18:13:00	1	12.7000	79.0000
3975	2016-03-24 18:14:00	1	12.8000	79.0000
3976	2016-03-24 18:15:00	1	-3.2000	58.0000
3977	2016-03-24 18:16:00	1	-5.6000	41.0000
3978	2016-03-24 18:17:00	1	5.9000	46.0000
3979	2016-03-24 18:18:00	1	2.9000	41.0000
3980	2016-03-24 18:19:00	1	25.3000	58.0000
3981	2016-03-24 18:20:00	1	25.2000	49.0000
3982	2016-03-24 18:21:00	1	25.0000	59.0000
3983	2016-03-24 18:22:00	1	8.0000	75.0000
3984	2016-03-24 18:23:00	1	25.0000	44.0000
3985	2016-03-24 18:24:00	1	7.4000	55.0000
3986	2016-03-24 18:25:00	1	-5.3000	50.0000
3987	2016-03-24 18:26:00	1	-1.8000	61.0000
3988	2016-03-24 18:27:00	1	17.7000	70.0000
3989	2016-03-24 18:28:00	1	3.2000	69.0000
3990	2016-03-24 18:29:00	1	3.2000	68.0000
3991	2016-03-24 18:30:00	1	-9.3000	62.0000
3992	2016-03-24 18:31:00	1	7.2000	57.0000
3993	2016-03-24 18:32:00	1	17.5000	55.0000
3994	2016-03-24 18:33:00	1	16.2000	60.0000
3995	2016-03-24 18:34:00	1	28.7000	42.0000
3996	2016-03-24 18:35:00	1	14.5000	47.0000
3997	2016-03-24 18:36:00	1	21.9000	54.0000
3998	2016-03-24 18:37:00	1	9.3000	73.0000
3999	2016-03-24 18:38:00	1	0.9000	57.0000
4000	2016-03-24 18:39:00	1	0.7000	51.0000
4001	2016-03-24 18:40:00	1	-3.0000	58.0000
4002	2016-03-24 18:41:00	1	-0.1000	50.0000
4003	2016-03-24 18:42:00	1	10.7000	60.0000
4004	2016-03-24 18:43:00	1	26.9000	71.0000
4005	2016-03-24 18:44:00	1	-1.9000	49.0000
4006	2016-03-24 18:45:00	1	19.9000	57.0000
4007	2016-03-24 18:46:00	1	20.1000	45.0000
4008	2016-03-24 18:47:00	1	3.8000	54.0000
4009	2016-03-24 18:48:00	1	-9.8000	56.0000
4010	2016-03-24 18:49:00	1	8.0000	56.0000
4011	2016-03-24 18:50:00	1	11.6000	52.0000
4012	2016-03-24 18:51:00	1	22.9000	49.0000
4013	2016-03-24 18:52:00	1	12.1000	49.0000
4014	2016-03-24 18:53:00	1	13.3000	55.0000
4015	2016-03-24 18:54:00	1	16.5000	79.0000
4016	2016-03-24 18:55:00	1	11.3000	79.0000
4017	2016-03-24 18:56:00	1	-0.7000	67.0000
4018	2016-03-24 18:57:00	1	-1.3000	55.0000
4019	2016-03-24 18:58:00	1	18.8000	69.0000
4020	2016-03-24 18:59:00	1	13.8000	56.0000
4021	2016-03-24 19:00:00	1	5.7000	45.0000
4022	2016-03-24 19:01:00	1	-4.4000	69.0000
4023	2016-03-24 19:02:00	1	10.8000	46.0000
4024	2016-03-24 19:03:00	1	13.4000	50.0000
4025	2016-03-24 19:04:00	1	9.4000	56.0000
4026	2016-03-24 19:05:00	1	10.0000	40.0000
4027	2016-03-24 19:06:00	1	-6.1000	69.0000
4028	2016-03-24 19:07:00	1	4.4000	75.0000
4029	2016-03-24 19:08:00	1	15.0000	72.0000
4030	2016-03-24 19:09:00	1	9.0000	45.0000
4031	2016-03-24 19:10:00	1	21.6000	56.0000
4032	2016-03-24 19:11:00	1	-4.9000	48.0000
4033	2016-03-24 19:12:00	1	21.4000	73.0000
4034	2016-03-24 19:13:00	1	20.8000	50.0000
4035	2016-03-24 19:14:00	1	9.4000	69.0000
4036	2016-03-24 19:15:00	1	7.1000	60.0000
4037	2016-03-24 19:16:00	1	18.2000	58.0000
4038	2016-03-24 19:17:00	1	-9.1000	45.0000
4039	2016-03-24 19:18:00	1	-7.9000	50.0000
4040	2016-03-24 19:19:00	1	20.0000	46.0000
4041	2016-03-24 19:20:00	1	15.6000	41.0000
4042	2016-03-24 19:21:00	1	12.5000	55.0000
4043	2016-03-24 19:22:00	1	12.8000	56.0000
4044	2016-03-24 19:23:00	1	5.5000	49.0000
4045	2016-03-24 19:24:00	1	24.6000	79.0000
4046	2016-03-24 19:25:00	1	9.4000	59.0000
4047	2016-03-24 19:26:00	1	24.8000	78.0000
4048	2016-03-24 19:27:00	1	17.0000	79.0000
4049	2016-03-24 19:28:00	1	28.2000	50.0000
4050	2016-03-24 19:29:00	1	-3.6000	74.0000
4051	2016-03-24 19:30:00	1	22.4000	54.0000
4052	2016-03-24 19:31:00	1	2.8000	54.0000
4053	2016-03-24 19:32:00	1	-3.7000	61.0000
4054	2016-03-24 19:33:00	1	19.5000	77.0000
4055	2016-03-24 19:34:00	1	27.9000	74.0000
4056	2016-03-24 19:35:00	1	20.0000	58.0000
4057	2016-03-24 19:36:00	1	19.4000	49.0000
4058	2016-03-24 19:37:00	1	3.1000	45.0000
4059	2016-03-24 19:38:00	1	-0.6000	63.0000
4060	2016-03-24 19:39:00	1	10.0000	52.0000
4061	2016-03-24 19:40:00	1	13.2000	68.0000
4062	2016-03-24 19:41:00	1	20.2000	58.0000
4063	2016-03-24 19:42:00	1	13.8000	58.0000
4064	2016-03-24 19:43:00	1	-5.9000	78.0000
4065	2016-03-24 19:44:00	1	25.1000	65.0000
4066	2016-03-24 19:45:00	1	29.7000	67.0000
4067	2016-03-24 19:46:00	1	24.1000	45.0000
4068	2016-03-24 19:47:00	1	-2.0000	52.0000
4069	2016-03-24 19:48:00	1	16.0000	40.0000
4070	2016-03-24 19:49:00	1	-1.2000	58.0000
4071	2016-03-24 19:50:00	1	7.1000	72.0000
4072	2016-03-24 19:51:00	1	-2.5000	69.0000
4073	2016-03-24 19:52:00	1	1.3000	50.0000
4074	2016-03-24 19:53:00	1	8.7000	46.0000
4075	2016-03-24 19:54:00	1	-0.8000	68.0000
4076	2016-03-24 19:55:00	1	14.8000	75.0000
4077	2016-03-24 19:56:00	1	28.0000	70.0000
4078	2016-03-24 19:57:00	1	0.3000	42.0000
4079	2016-03-24 19:58:00	1	22.3000	49.0000
4080	2016-03-24 19:59:00	1	-6.3000	55.0000
4081	2016-03-24 20:00:00	1	15.0000	72.0000
4082	2016-03-24 20:01:00	1	4.9000	74.0000
4083	2016-03-24 20:02:00	1	5.8000	42.0000
4084	2016-03-24 20:03:00	1	9.5000	64.0000
4085	2016-03-24 20:04:00	1	10.5000	55.0000
4086	2016-03-24 20:05:00	1	15.8000	76.0000
4087	2016-03-24 20:06:00	1	17.1000	59.0000
4088	2016-03-24 20:07:00	1	-5.9000	48.0000
4089	2016-03-24 20:08:00	1	3.8000	58.0000
4090	2016-03-24 20:09:00	1	9.1000	42.0000
4091	2016-03-24 20:10:00	1	11.4000	52.0000
4092	2016-03-24 20:11:00	1	5.5000	42.0000
4093	2016-03-24 20:12:00	1	8.9000	71.0000
4094	2016-03-24 20:13:00	1	-8.9000	49.0000
4095	2016-03-24 20:14:00	1	-9.7000	64.0000
4096	2016-03-24 20:15:00	1	28.7000	55.0000
4097	2016-03-24 20:16:00	1	-1.8000	45.0000
4098	2016-03-24 20:17:00	1	-5.6000	54.0000
4099	2016-03-24 20:18:00	1	26.5000	54.0000
4100	2016-03-24 20:19:00	1	15.8000	70.0000
4101	2016-03-24 20:20:00	1	2.3000	61.0000
4102	2016-03-24 20:21:00	1	4.6000	76.0000
4103	2016-03-24 20:22:00	1	-5.1000	70.0000
4104	2016-03-24 20:23:00	1	27.8000	70.0000
4105	2016-03-24 20:24:00	1	-8.6000	58.0000
4106	2016-03-24 20:25:00	1	-8.2000	54.0000
4107	2016-03-24 20:26:00	1	10.8000	50.0000
4108	2016-03-24 20:27:00	1	-7.9000	52.0000
4109	2016-03-24 20:28:00	1	-7.0000	40.0000
4110	2016-03-24 20:29:00	1	1.0000	60.0000
4111	2016-03-24 20:30:00	1	-2.0000	65.0000
4112	2016-03-24 20:31:00	1	18.7000	42.0000
4113	2016-03-24 20:32:00	1	13.2000	43.0000
4114	2016-03-24 20:33:00	1	-9.9000	58.0000
4115	2016-03-24 20:34:00	1	7.1000	75.0000
4116	2016-03-24 20:35:00	1	26.8000	47.0000
4117	2016-03-24 20:36:00	1	27.6000	53.0000
4118	2016-03-24 20:37:00	1	18.7000	56.0000
4119	2016-03-24 20:38:00	1	20.2000	67.0000
4120	2016-03-24 20:39:00	1	11.1000	51.0000
4121	2016-03-24 20:40:00	1	-6.7000	78.0000
4122	2016-03-24 20:41:00	1	4.4000	74.0000
4123	2016-03-24 20:42:00	1	-9.9000	62.0000
4124	2016-03-24 20:43:00	1	13.8000	68.0000
4125	2016-03-24 20:44:00	1	9.8000	47.0000
4126	2016-03-24 20:45:00	1	-3.5000	47.0000
4127	2016-03-24 20:46:00	1	-5.6000	64.0000
4128	2016-03-24 20:47:00	1	-6.1000	43.0000
4129	2016-03-24 20:48:00	1	18.3000	44.0000
4130	2016-03-24 20:49:00	1	-2.5000	45.0000
4131	2016-03-24 20:50:00	1	20.0000	48.0000
4132	2016-03-24 20:51:00	1	24.6000	75.0000
4133	2016-03-24 20:52:00	1	5.8000	54.0000
4134	2016-03-24 20:53:00	1	20.0000	45.0000
4135	2016-03-24 20:54:00	1	-0.2000	57.0000
4136	2016-03-24 20:55:00	1	27.6000	45.0000
4137	2016-03-24 20:56:00	1	24.0000	41.0000
4138	2016-03-24 20:57:00	1	27.2000	63.0000
4139	2016-03-24 20:58:00	1	18.6000	46.0000
4140	2016-03-24 20:59:00	1	27.3000	65.0000
4141	2016-03-24 21:00:00	1	5.8000	40.0000
4142	2016-03-24 21:01:00	1	26.1000	66.0000
4143	2016-03-24 21:02:00	1	29.0000	60.0000
4144	2016-03-24 21:03:00	1	-2.1000	71.0000
4145	2016-03-24 21:04:00	1	-6.0000	70.0000
4146	2016-03-24 21:05:00	1	22.6000	63.0000
4147	2016-03-24 21:06:00	1	9.6000	47.0000
4148	2016-03-24 21:07:00	1	11.6000	60.0000
4149	2016-03-24 21:08:00	1	0.5000	69.0000
4150	2016-03-24 21:09:00	1	-8.7000	62.0000
4151	2016-03-24 21:10:00	1	12.7000	40.0000
4152	2016-03-24 21:11:00	1	23.4000	62.0000
4153	2016-03-24 21:12:00	1	0.9000	67.0000
4154	2016-03-24 21:13:00	1	1.0000	44.0000
4155	2016-03-24 21:14:00	1	1.6000	57.0000
4156	2016-03-24 21:15:00	1	-2.1000	47.0000
4157	2016-03-24 21:16:00	1	2.2000	60.0000
4158	2016-03-24 21:17:00	1	-2.4000	61.0000
4159	2016-03-24 21:18:00	1	-6.0000	42.0000
4160	2016-03-24 21:19:00	1	28.4000	45.0000
4161	2016-03-24 21:20:00	1	20.9000	47.0000
4162	2016-03-24 21:21:00	1	-8.0000	49.0000
4163	2016-03-24 21:22:00	1	8.2000	66.0000
4164	2016-03-24 21:23:00	1	-4.1000	75.0000
4165	2016-03-24 21:24:00	1	25.2000	73.0000
4166	2016-03-24 21:25:00	1	-1.0000	42.0000
4167	2016-03-24 21:26:00	1	-3.8000	44.0000
4168	2016-03-24 21:27:00	1	24.7000	74.0000
4169	2016-03-24 21:28:00	1	22.9000	49.0000
4170	2016-03-24 21:29:00	1	6.7000	64.0000
4171	2016-03-24 21:30:00	1	4.0000	46.0000
4172	2016-03-24 21:31:00	1	21.8000	43.0000
4173	2016-03-24 21:32:00	1	18.6000	64.0000
4174	2016-03-24 21:33:00	1	27.3000	67.0000
4175	2016-03-24 21:34:00	1	4.9000	56.0000
4176	2016-03-24 21:35:00	1	-9.4000	57.0000
4177	2016-03-24 21:36:00	1	16.7000	60.0000
4178	2016-03-24 21:37:00	1	6.3000	56.0000
4179	2016-03-24 21:38:00	1	16.2000	54.0000
4180	2016-03-24 21:39:00	1	23.7000	42.0000
4181	2016-03-24 21:40:00	1	19.5000	68.0000
4182	2016-03-24 21:41:00	1	29.3000	40.0000
4183	2016-03-24 21:42:00	1	-5.0000	47.0000
4184	2016-03-24 21:43:00	1	2.8000	64.0000
4185	2016-03-24 21:44:00	1	29.7000	71.0000
4186	2016-03-24 21:45:00	1	-7.6000	61.0000
4187	2016-03-24 21:46:00	1	4.1000	79.0000
4188	2016-03-24 21:47:00	1	29.8000	44.0000
4189	2016-03-24 21:48:00	1	23.6000	68.0000
4190	2016-03-24 21:49:00	1	25.2000	49.0000
4191	2016-03-24 21:50:00	1	22.8000	44.0000
4192	2016-03-24 21:51:00	1	4.4000	66.0000
4193	2016-03-24 21:52:00	1	28.4000	51.0000
4194	2016-03-24 21:53:00	1	14.5000	50.0000
4195	2016-03-24 21:54:00	1	3.0000	54.0000
4196	2016-03-24 21:55:00	1	-4.0000	52.0000
4197	2016-03-24 21:56:00	1	10.8000	77.0000
4198	2016-03-24 21:57:00	1	28.2000	55.0000
4199	2016-03-24 21:58:00	1	29.3000	45.0000
4200	2016-03-24 21:59:00	1	13.7000	40.0000
4201	2016-03-24 22:00:00	1	-9.5000	47.0000
4202	2016-03-24 22:01:00	1	2.6000	53.0000
4203	2016-03-24 22:02:00	1	10.3000	45.0000
4204	2016-03-24 22:03:00	1	7.3000	69.0000
4205	2016-03-24 22:04:00	1	-0.5000	69.0000
4206	2016-03-24 22:05:00	1	12.4000	56.0000
4207	2016-03-24 22:06:00	1	-1.7000	64.0000
4208	2016-03-24 22:07:00	1	11.8000	77.0000
4209	2016-03-24 22:08:00	1	17.5000	45.0000
4210	2016-03-24 22:09:00	1	21.3000	40.0000
4211	2016-03-24 22:10:00	1	14.5000	40.0000
4212	2016-03-24 22:11:00	1	-7.1000	41.0000
4213	2016-03-24 22:12:00	1	-7.4000	64.0000
4214	2016-03-24 22:13:00	1	21.2000	40.0000
4215	2016-03-24 22:14:00	1	2.1000	73.0000
4216	2016-03-24 22:15:00	1	-9.2000	45.0000
4217	2016-03-24 22:16:00	1	-9.0000	41.0000
4218	2016-03-24 22:17:00	1	17.2000	66.0000
4219	2016-03-24 22:18:00	1	15.8000	56.0000
4220	2016-03-24 22:19:00	1	25.2000	40.0000
4221	2016-03-24 22:20:00	1	7.0000	74.0000
4222	2016-03-24 22:21:00	1	27.6000	59.0000
4223	2016-03-24 22:22:00	1	4.4000	78.0000
4224	2016-03-24 22:23:00	1	22.1000	52.0000
4225	2016-03-24 22:24:00	1	15.7000	62.0000
4226	2016-03-24 22:25:00	1	-7.6000	41.0000
4227	2016-03-24 22:26:00	1	10.7000	65.0000
4228	2016-03-24 22:27:00	1	5.6000	58.0000
4229	2016-03-24 22:28:00	1	-3.6000	77.0000
4230	2016-03-24 22:29:00	1	15.1000	58.0000
4231	2016-03-24 22:30:00	1	11.6000	59.0000
4232	2016-03-24 22:31:00	1	21.2000	50.0000
4233	2016-03-24 22:32:00	1	29.4000	42.0000
4234	2016-03-24 22:33:00	1	-6.0000	47.0000
4235	2016-03-24 22:34:00	1	12.9000	52.0000
4236	2016-03-24 22:35:00	1	10.5000	64.0000
4237	2016-03-24 22:36:00	1	6.8000	42.0000
4238	2016-03-24 22:37:00	1	15.2000	43.0000
4239	2016-03-24 22:38:00	1	27.5000	58.0000
4240	2016-03-24 22:39:00	1	23.1000	42.0000
4241	2016-03-24 22:40:00	1	-9.3000	48.0000
4242	2016-03-24 22:41:00	1	23.5000	62.0000
4243	2016-03-24 22:42:00	1	-9.1000	65.0000
4244	2016-03-24 22:43:00	1	-5.3000	41.0000
4245	2016-03-24 22:44:00	1	5.8000	59.0000
4246	2016-03-24 22:45:00	1	15.9000	72.0000
4247	2016-03-24 22:46:00	1	5.8000	42.0000
4248	2016-03-24 22:47:00	1	10.1000	58.0000
4249	2016-03-24 22:48:00	1	25.4000	78.0000
4250	2016-03-24 22:49:00	1	-9.6000	42.0000
4251	2016-03-24 22:50:00	1	13.2000	70.0000
4252	2016-03-24 22:51:00	1	8.1000	76.0000
4253	2016-03-24 22:52:00	1	29.0000	68.0000
4254	2016-03-24 22:53:00	1	21.2000	72.0000
4255	2016-03-24 22:54:00	1	10.6000	54.0000
4256	2016-03-24 22:55:00	1	9.6000	46.0000
4257	2016-03-24 22:56:00	1	9.9000	77.0000
4258	2016-03-24 22:57:00	1	-7.3000	74.0000
4259	2016-03-24 22:58:00	1	12.1000	49.0000
4260	2016-03-24 22:59:00	1	18.0000	64.0000
4261	2016-03-24 23:00:00	1	27.2000	73.0000
4262	2016-03-24 23:01:00	1	25.3000	45.0000
4263	2016-03-24 23:02:00	1	20.9000	78.0000
4264	2016-03-24 23:03:00	1	18.2000	79.0000
4265	2016-03-24 23:04:00	1	29.5000	67.0000
4266	2016-03-24 23:05:00	1	-5.4000	46.0000
4267	2016-03-24 23:06:00	1	-0.5000	46.0000
4268	2016-03-24 23:07:00	1	12.6000	49.0000
4269	2016-03-24 23:08:00	1	16.1000	61.0000
4270	2016-03-24 23:09:00	1	-5.1000	41.0000
4271	2016-03-24 23:10:00	1	28.1000	74.0000
4272	2016-03-24 23:11:00	1	18.0000	78.0000
4273	2016-03-24 23:12:00	1	27.6000	55.0000
4274	2016-03-24 23:13:00	1	28.7000	54.0000
4275	2016-03-24 23:14:00	1	28.1000	47.0000
4276	2016-03-24 23:15:00	1	7.7000	72.0000
4277	2016-03-24 23:16:00	1	-9.4000	53.0000
4278	2016-03-24 23:17:00	1	-1.8000	55.0000
4279	2016-03-24 23:18:00	1	18.4000	60.0000
4280	2016-03-24 23:19:00	1	7.9000	67.0000
4281	2016-03-24 23:20:00	1	15.1000	54.0000
4282	2016-03-24 23:21:00	1	0.5000	43.0000
4283	2016-03-24 23:22:00	1	-4.7000	75.0000
4284	2016-03-24 23:23:00	1	-6.9000	75.0000
4285	2016-03-24 23:24:00	1	-3.1000	53.0000
4286	2016-03-24 23:25:00	1	28.0000	52.0000
4287	2016-03-24 23:26:00	1	22.5000	63.0000
4288	2016-03-24 23:27:00	1	12.9000	59.0000
4289	2016-03-24 23:28:00	1	6.7000	42.0000
4290	2016-03-24 23:29:00	1	0.0000	41.0000
4291	2016-03-24 23:30:00	1	-1.6000	51.0000
4292	2016-03-24 23:31:00	1	0.0000	69.0000
4293	2016-03-24 23:32:00	1	-9.4000	50.0000
4294	2016-03-24 23:33:00	1	-9.4000	55.0000
4295	2016-03-24 23:34:00	1	4.7000	58.0000
4296	2016-03-24 23:35:00	1	6.9000	56.0000
4297	2016-03-24 23:36:00	1	-9.0000	75.0000
4298	2016-03-24 23:37:00	1	24.3000	53.0000
4299	2016-03-24 23:38:00	1	10.5000	52.0000
4300	2016-03-24 23:39:00	1	27.6000	47.0000
4301	2016-03-24 23:40:00	1	-4.6000	44.0000
4302	2016-03-24 23:41:00	1	22.4000	72.0000
4303	2016-03-24 23:42:00	1	11.6000	50.0000
4304	2016-03-24 23:43:00	1	18.1000	64.0000
4305	2016-03-24 23:44:00	1	26.9000	64.0000
4306	2016-03-24 23:45:00	1	3.1000	61.0000
4307	2016-03-24 23:46:00	1	15.7000	58.0000
4308	2016-03-24 23:47:00	1	4.3000	59.0000
4309	2016-03-24 23:48:00	1	-8.7000	53.0000
4310	2016-03-24 23:49:00	1	5.4000	58.0000
4311	2016-03-24 23:50:00	1	23.4000	75.0000
4312	2016-03-24 23:51:00	1	5.7000	63.0000
4313	2016-03-24 23:52:00	1	9.7000	53.0000
4314	2016-03-24 23:53:00	1	-9.3000	60.0000
4315	2016-03-24 23:54:00	1	-2.6000	44.0000
4316	2016-03-24 23:55:00	1	17.7000	49.0000
4317	2016-03-24 23:56:00	1	24.0000	66.0000
4318	2016-03-24 23:57:00	1	0.7000	74.0000
4319	2016-03-24 23:58:00	1	25.4000	72.0000
4320	2016-03-24 23:59:00	1	4.0000	47.0000
\.


--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('misurazioni_id_misurazione_seq', 4320, true);


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

COPY sensori (id_sensore, nome_sensore, descrizione, posizione, abilitato, incluso_in_media, id_driver, ultimo_aggiornamento, parametri) FROM stdin;
1	Test	Sensore di test	\N	t	t	1	2016-03-24 21:55:52.537124	\N
\.


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('sensori_id_sensore_seq', 1, true);


--
-- Data for Name: situazione; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY situazione (data_ora, id_sensore, temperatura, umidita, tendenza_temperatura, tendenza_umidita) FROM stdin;
2016-03-24 23:59:00	1	4.0000	47.0000	\N	\N
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
    ADD CONSTRAINT driver_sensori_nome_driver_key UNIQUE (nome);


--
-- Name: driver_sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: smac
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_pkey PRIMARY KEY (id);


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
    ADD CONSTRAINT fk_driver_sensore FOREIGN KEY (id_driver) REFERENCES driver_sensori(id);


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

