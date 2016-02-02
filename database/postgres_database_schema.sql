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

DROP DATABASE smac;
--
-- Name: smac; Type: DATABASE; Schema: -; Owner: -
--

CREATE DATABASE smac WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


\connect smac

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: report_sensore; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE report_sensore AS (
	data_ora timestamp without time zone,
	id_sensore smallint,
	nome_sesore character varying,
	temperatura numeric(9,4),
	umidita numeric(9,4)
);


--
-- Name: situazione_sensore; Type: TYPE; Schema: public; Owner: -
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


--
-- Name: aggiorna_dati_giornalieri(smallint, date); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: aggiorna_situazione(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: aggiorna_tendenza(interval, interval); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: dati_programma(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dati_programma(progr_id integer DEFAULT NULL::integer) RETURNS TABLE(id_programma integer, nome_programma character varying, descrizione_programma text, temperature_rif numeric[], t_anticongelamento numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    progdata RECORD;
    curr_progr text;
    t_anticongelamento numeric(9,4);
BEGIN

    IF progr_id IS NULL THEN
        SELECT get_setting('programma_attuale','-1'::text) INTO progr_id;
    END IF;

    t_anticongelamento =  get_setting('temperatura_anticongelamento'::varchar(64),'5'::text);    

    CASE progr_id::smallint

        -- sistema spento
        WHEN -1 THEN

            RETURN QUERY SELECT -1, 'Spento'::varchar(64), 'Sistema Spento'::text, ARRAY[]::numeric(9,4)[], t_anticongelamento;

        -- sistema in risparmio energia (anticongelamento)
        WHEN 0 THEN

            RETURN QUERY SELECT 0, 'Anticongelamento'::varchar(64),
		       'Sistema in modalità anticongelamento'::text,
		       ARRAY[ t_anticongelamento, null,null, null, null],
		       t_anticongelamento;

	-- richiesta specifico id programma
        ELSE 
            RETURN QUERY
               SELECT p.id_programma,
                      p.nome_programma,
                      p.descrizione_programma,
                      array_prepend(t_anticongelamento, p.temperature_rif) AS temperature_rif,
                      t_anticongelamento
                 FROM programmi p
                WHERE p.id_programma = progr_id;

       END CASE;

       RETURN;
       
END$$;


--
-- Name: dati_sensore(smallint, interval, interval); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dati_sensore(l_id_sensore smallint DEFAULT NULL::smallint, campione interval DEFAULT '01:00:00'::interval, target interval DEFAULT '00:10:00'::interval) RETURNS SETOF situazione_sensore
    LANGUAGE plpgsql
    AS $_$
DECLARE
    dati_sensore situazione_sensore;
    cond_where text DEFAULT null;
    query text DEFAULT null;

BEGIN

    dati_sensore.id_sensore = null;
    dati_sensore.nome_sensore = null;
    dati_sensore.num_sensori = 0;

    -- verifico che non sia la media dei sensori
    IF(l_id_sensore IS NULL) THEN

        -- ricalcolo se necessario tutte le tendenze
        PERFORM aggiorna_tendenza(campione, target);

        -- ottengo i valori medi attuali
        SELECT 0::smallint,
               'Media',              
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


--
-- Name: dbg_genera_misurazioni(date, date); Type: FUNCTION; Schema: public; Owner: -
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


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: programmi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE programmi (
    id_programma integer NOT NULL,
    nome_programma character varying(64),
    descrizione_programma text,
    temperature_rif numeric(9,4)[] DEFAULT '{NULL,NULL,NULL,NULL,NULL}'::numeric[]
);


--
-- Name: elenco_programmi(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION elenco_programmi() RETURNS SETOF programmi
    LANGUAGE plpgsql
    AS $$

BEGIN

    RETURN QUERY SELECT  id_programma, nome_programma::varchar(64), descrizione_programma, temperature_rif::numeric(9,4)[] FROM dati_programma(-1::smallint);
    RETURN QUERY SELECT  id_programma, nome_programma::varchar(64), descrizione_programma, temperature_rif::numeric(9,4)[] FROM dati_programma(0::smallint);
    RETURN QUERY SELECT * FROM programmi ORDER BY nome_programma;
    RETURN;
       
END$$;


--
-- Name: get_setting(character varying, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: previsione_mq(smallint, character varying, interval, interval); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: programmazioni(integer, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION programmazioni(progr_id integer DEFAULT NULL::integer, prog_giorno smallint DEFAULT NULL::smallint) RETURNS TABLE(id_programma integer, giorno smallint, ora time without time zone, intervallo integer, t_rif_indice smallint, t_rif_val numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    t_anticongelamento NUMERIC(9,4);
    t_rif smallint DEFAULT null;
    t_val NUMERIC(9,4) DEFAULT null;
    g_rif_min smallint DEFAULT 1;
    g_rif_max smallint DEFAULT 7;

BEGIN

    IF progr_id IS NULL THEN
       progr_id = get_setting('programma_attuale'::varchar,'-1'::text);
    END IF;

    t_anticongelamento = get_setting('temperatura_anticongelamento'::varchar,'5'::text);

    -- if prog_giorno == 0 retrieve all day
    IF prog_giorno >= 1 AND prog_giorno <= 7 THEN
       g_rif_min = prog_giorno;
       g_rif_max = prog_giorno;
    ELSIF prog_giorno IS NULL THEN
       g_rif_min = date_part('ISODOW', NOW());
       g_rif_max = g_rif_min;
    END IF;

    CASE progr_id::smallint
    
	-- sistema spento o anticongelamento 
        WHEN -1, 0 THEN

            -- t_rif = 0 per anticongelamento
	    IF progr_id = 0 THEN
	        t_rif = 0;
	        t_val = t_anticongelamento;
	    END IF;

            WHILE g_rif_min <= g_rif_max LOOP
                RETURN QUERY
                    SELECT progr_id,
                           g_rif_min,
                           (h || ':00')::time,
                           EXTRACT(EPOCH FROM (h || ':00')::time)::integer,
                           t_rif::smallint, t_val
                      FROM generate_series(0,23) AS h;

	        g_rif_min = g_rif_min + 1;
	    END LOOP;

        -- richiesta specifico dettaglio
	ELSE
	    RETURN QUERY SELECT d.id_programma,
                                d.giorno,
                                d.ora,
                                EXTRACT(EPOCH FROM d.ora)::integer,
                                COALESCE(d.t_riferimento,0)::smallint,
                                CASE WHEN d.t_riferimento IS NULL OR d.t_riferimento = 0 THEN t_anticongelamento 
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


--
-- Name: report_misurazioni(smallint, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION report_misurazioni(pid_sensore smallint DEFAULT NULL::smallint, data_ora_inizio timestamp without time zone DEFAULT (now() - '01:00:00'::interval), data_ora_fine timestamp without time zone DEFAULT now()) RETURNS SETOF report_sensore
    LANGUAGE plpgsql
    AS $$DECLARE
BEGIN
    -- se non viene passato un sensore devo calcolare la "media"
    IF pid_sensore IS NULL THEN
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


--
-- Name: set_setting(character varying, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: dati_giornalieri; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: dettaglio_programma; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE dettaglio_programma (
    id_programma integer NOT NULL,
    giorno smallint NOT NULL,
    ora time without time zone NOT NULL,
    t_riferimento smallint
);


--
-- Name: driver_sensori; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE driver_sensori (
    id_driver smallint NOT NULL,
    nome_driver character varying(16),
    parametri_driver character varying(64)
);


--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE driver_sensori_id_driver_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE driver_sensori_id_driver_seq OWNED BY driver_sensori.id_driver;


--
-- Name: impostazioni; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE impostazioni (
    nome character varying(128) NOT NULL,
    valore text NOT NULL
);


--
-- Name: COLUMN impostazioni.nome; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN impostazioni.nome IS 'Nome della voce di impostazione';


--
-- Name: COLUMN impostazioni.valore; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN impostazioni.valore IS 'Valore della voce di impostazione';


--
-- Name: misurazioni; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE misurazioni (
    id_misurazione bigint NOT NULL,
    data_ora timestamp without time zone DEFAULT now() NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4)
);


--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE misurazioni_id_misurazione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE misurazioni_id_misurazione_seq OWNED BY misurazioni.id_misurazione;


--
-- Name: programma_id_programma_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE programma_id_programma_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: programma_id_programma_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE programma_id_programma_seq OWNED BY programmi.id_programma;


--
-- Name: sensori; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE sensori; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE sensori IS 'elenco dei sensori usati';


--
-- Name: COLUMN sensori.ultimo_aggiornamento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN sensori.ultimo_aggiornamento IS 'Data e ora dell''ultimo aggiornamento delle previsioni delle misurazioni';


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sensori_id_sensore_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sensori_id_sensore_seq OWNED BY sensori.id_sensore;


--
-- Name: situazione; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE situazione (
    data_ora timestamp without time zone NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4),
    tendenza_temperatura numeric(9,4),
    tendenza_umidita numeric(9,4)
);


--
-- Name: id_driver; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY driver_sensori ALTER COLUMN id_driver SET DEFAULT nextval('driver_sensori_id_driver_seq'::regclass);


--
-- Name: id_misurazione; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY misurazioni ALTER COLUMN id_misurazione SET DEFAULT nextval('misurazioni_id_misurazione_seq'::regclass);


--
-- Name: id_programma; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY programmi ALTER COLUMN id_programma SET DEFAULT nextval('programma_id_programma_seq'::regclass);


--
-- Name: id_sensore; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sensori ALTER COLUMN id_sensore SET DEFAULT nextval('sensori_id_sensore_seq'::regclass);


--
-- Name: dati_giornalieri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT dati_giornalieri_pkey PRIMARY KEY (data, id_sensore);


--
-- Name: dettaglio_programma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dettaglio_programma
    ADD CONSTRAINT dettaglio_programma_pkey PRIMARY KEY (id_programma, giorno, ora);


--
-- Name: driver_sensori_nome_driver_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_nome_driver_key UNIQUE (nome_driver);


--
-- Name: driver_sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_pkey PRIMARY KEY (id_driver);


--
-- Name: impostazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY impostazioni
    ADD CONSTRAINT impostazioni_pkey PRIMARY KEY (valore);


--
-- Name: misurazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT misurazioni_pkey PRIMARY KEY (id_misurazione);


--
-- Name: programma_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT programma_pkey PRIMARY KEY (id_programma);


--
-- Name: sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sensori
    ADD CONSTRAINT sensori_pkey PRIMARY KEY (id_sensore);


--
-- Name: situazione_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY situazione
    ADD CONSTRAINT situazione_pkey PRIMARY KEY (id_sensore);


--
-- Name: un_data_sensore; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT un_data_sensore UNIQUE (data_ora, id_sensore);


--
-- Name: un_nome_programma; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT un_nome_programma UNIQUE (nome_programma);


--
-- Name: un_nome_sensore; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX un_nome_sensore ON sensori USING btree (nome_sensore);


--
-- Name: aggiornamento_situazione; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aggiornamento_situazione AFTER INSERT ON misurazioni FOR EACH ROW WHEN (((new.temperatura IS NOT NULL) OR (new.umidita IS NOT NULL))) EXECUTE PROCEDURE aggiorna_situazione();


--
-- Name: dettaglio_programma_id_programma_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dettaglio_programma
    ADD CONSTRAINT dettaglio_programma_id_programma_fkey FOREIGN KEY (id_programma) REFERENCES programmi(id_programma);


--
-- Name: fk_driver_sensore; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sensori
    ADD CONSTRAINT fk_driver_sensore FOREIGN KEY (id_driver) REFERENCES driver_sensori(id_driver);


--
-- Name: fk_situazione_sensore; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY situazione
    ADD CONSTRAINT fk_situazione_sensore FOREIGN KEY (id_sensore) REFERENCES sensori(id_sensore);


--
-- Name: fk_synop_temp_max; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_synop_temp_max FOREIGN KEY (id_synop_temp_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_synop_temp_min; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_synop_temp_min FOREIGN KEY (id_synop_temp_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_syrep_temp_max; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_syrep_temp_max FOREIGN KEY (id_syrep_temp_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_syrep_temp_min; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_syrep_temp_min FOREIGN KEY (id_syrep_temp_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: fk_umidita_min; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT fk_umidita_min FOREIGN KEY (id_umidita_min) REFERENCES misurazioni(id_misurazione);


--
-- Name: id_umidita_max; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT id_umidita_max FOREIGN KEY (id_umidita_max) REFERENCES misurazioni(id_misurazione);


--
-- Name: pk_misurazione_sensore; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT pk_misurazione_sensore FOREIGN KEY (id_sensore) REFERENCES sensori(id_sensore);


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

