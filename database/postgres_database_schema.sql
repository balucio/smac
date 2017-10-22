--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: smac; Type: DATABASE; Schema: -; Owner: smac
--

CREATE USER smac PASSWORD 'smac';
CREATE DATABASE smac WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE smac OWNER TO smac;

\connect smac

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

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
-- Name: eventi_commutazione; Type: TYPE; Schema: public; Owner: smac
--

CREATE TYPE eventi_commutazione AS (
	inizio timestamp without time zone,
	durata interval,
	stato boolean
);


ALTER TYPE public.eventi_commutazione OWNER TO smac;

--
-- Name: parametri_sensore; Type: TYPE; Schema: public; Owner: smac
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


ALTER TYPE public.parametri_sensore OWNER TO smac;

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


ALTER TYPE public.report_programma OWNER TO smac;

--
-- Name: report_sensore; Type: TYPE; Schema: public; Owner: smac
--

CREATE TYPE report_sensore AS (
	data_ora timestamp without time zone,
	id_sensore smallint,
	nome_sensore character varying,
	temperatura numeric,
	umidita numeric
);


ALTER TYPE public.report_sensore OWNER TO smac;

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


ALTER TYPE public.situazione_sensore OWNER TO smac;

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

    l_id_synop_temp_min bigint;
    l_id_synop_temp_max bigint;

    l_id_syrep_temp_min bigint;
    l_id_syrep_temp_max bigint;

    l_id_umidita_min bigint;
    l_id_umidita_max bigint;

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
-- Name: aggiorna_storico_commutazioni(); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION public.aggiorna_storico_commutazioni()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$

DECLARE
    -- l'actuator può fallire 6 tentativi (con un delay 300), prima che lo stato caldaia
    -- venga impostato a sconosciuto
  MAX_INTERVAL INTERVAL DEFAULT '60 minutes'::interval;
  delta INTERVAL;
  ultima_data_ora TIMESTAMP WITHOUT TIME ZONE;
  ultimo_stato BOOLEAN;
BEGIN
  -- ultima commutazione inserita
  SELECT data_ora, stato
    INTO ultima_data_ora, ultimo_stato
    FROM ultima_commutazione
  ORDER BY data_ora desc LIMIT 1;

  -- Inserisco se la data ora che sto scrivendo è inferiore a quella dell'ultima registrazione
    -- Per debug in teroria non dovrebbe mai accadere
  IF ultima_data_ora > NEW.data_ora THEN
    RETURN NEW;
  END IF;

  delta = date_trunc('seconds', NEW.data_ora - ultima_data_ora);

  IF delta IS NULL THEN
    -- delta è null se questo è il primo record e inserisco il primo valore
    INSERT INTO ultima_commutazione(data_ora, stato) VALUES(NOW(), NEW.stato);
    RETURN NEW;
  END IF;

   -- mantengo aggiornato il tempo di ultima commutazione e lo stato con i nuovi dati
  UPDATE ultima_commutazione SET stato = NEW.stato, data_ora = NOW();
  
   -- se non c'è un cambiamento di stato non è necessario aggiornare
   IF NEW.stato IS NOT DISTINCT FROM ultimo_stato THEN
      RETURN NULL;
   END IF;

   -- se è passato MAX_INTERVAL dall'aggiornamento e lo stato è cambiato
   -- assumo di non sapere più lo stato della caldaia.
  IF delta > MAX_INTERVAL THEN

      -- Suppongo che l'actuator non aggiorni più lo stato da un tempo pari all'ulimo 
      -- aggiornamento più la metà di MAX_INTERVAL
    INSERT INTO storico_commutazioni(data_ora, stato)
         VALUES (ultima_data_ora + (MAX_INTERVAL / 2) , NULL::boolean);

    -- a questo punto inserisco la nuova misurazione
    RETURN NEW;
  END IF;

  -- Nessun inserimento altrimenti
  RETURN NULL;
  
END;

$BODY$;

ALTER FUNCTION public.aggiorna_storico_commutazioni() OWNER TO smac;

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
           BEGIN
               SELECT previsione_mq(l_sensore, 'temperatura', campione, previsione) INTO previsione_temperatura;
               SELECT previsione_mq(l_sensore, 'umidita', campione, previsione) INTO previsione_umidita;

               UPDATE situazione
                    SET tendenza_temperatura = previsione_temperatura,
                        tendenza_umidita =  previsione_umidita
               WHERE id_sensore = l_sensore;

               UPDATE sensori SET ultimo_aggiornamento = NOW() WHERE id_sensore = l_sensore;
               -- gestisco un eventuale divisione per zero in previsione_mq
           EXCEPTION
               WHEN division_by_zero THEN
                  RAISE NOTICE 'Probabile divsione per zero in previsione_mq';
                  -- continuo con il sensore successivo
                  NULL;
          END;
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
-- Name: programmi; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE programmi (
    id_programma integer NOT NULL,
    nome_programma character varying(64) NOT NULL,
    descrizione_programma text,
    temperature_rif numeric(9,4)[] DEFAULT '{NULL,NULL,NULL,NULL,NULL}'::numeric[],
    sensore_rif smallint DEFAULT 0 NOT NULL
);


ALTER TABLE public.programmi OWNER TO smac;

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
         ORDER BY abilitato DESC, incluso_in_media DESC, nome_sensore ASC;
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
    SELECT id FROM elenco_sensori(stato) WHERE id = sens_id
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
-- Name: notifica_modifica(); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION notifica_modifica() RETURNS trigger
    LANGUAGE plpgsql COST 10
    AS $$
BEGIN
 -- TG_TABLE_NAME nome della tabella che ha richiamato il trigger
 -- TG_OP is the operation that triggered this function: INSERT, UPDATE or DELETE.
 PERFORM pg_notify(TG_TABLE_NAME,  TG_OP);
 return new;
END;
$$;


ALTER FUNCTION public.notifica_modifica() OWNER TO smac;

--
-- Name: notifica_modifica_configurazione(); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION notifica_modifica_configurazione() RETURNS trigger
    LANGUAGE plpgsql COST 10
    AS $$BEGIN
	PERFORM pg_notify(OLD.nome,  new.valore);
	return new;
END;$$;


ALTER FUNCTION public.notifica_modifica_configurazione() OWNER TO smac;

--
-- Name: previsione_mq(smallint, character varying, interval, interval); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION previsione_mq(sensore smallint, grandezza character varying, campione interval DEFAULT '01:00:00'::interval, target interval DEFAULT '00:10:00'::interval) RETURNS numeric
    LANGUAGE plpgsql
    AS $_$DECLARE
	media_date double precision DEFAULT 0.0;
	media_valori double precision DEFAULT 0.0;
	scarto double precision DEFAULT 0.0;
	scarto_quadratico double precision DEFAULT 0.0;
	coeff_angolare double precision DEFAULT 0.0;
	termine_noto double precision DEFAULT 0.0;
BEGIN
	-- Muting errors
	SET LOCAL client_min_messages TO WARNING;


    -- Creating temp table to store values
	DROP TABLE IF EXISTS campioni;
	CREATE TEMPORARY TABLE campioni(
		epoch_date double precision,
		valore numeric(9,4)
	);

    EXECUTE format('
        INSERT INTO campioni
             SELECT EXTRACT(EPOCH FROM data_ora)::bigint, %I
               FROM misurazioni
              WHERE data_ora >= ( now() - $1 )
                AND id_sensore = $2
                AND %I IS NOT NULL;',
        grandezza,
        grandezza
    ) USING campione, sensore;


    -- Calcolo i valori medi per tempi e valori
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
-- Name: report_commutazioni(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION report_commutazioni(data_inizio timestamp without time zone DEFAULT ((now() - '24:00:00'::interval))::timestamp without time zone, data_fine timestamp without time zone DEFAULT now()) RETURNS SETOF eventi_commutazione
    LANGUAGE plpgsql
    AS $$
DECLARE
	start_date timestamp without time zone;
BEGIN

	-- Trovo la data precedente più vicina a data_inizio
	SELECT data_ora INTO start_date
	  FROM storico_commutazioni
	 WHERE data_ora <= data_inizio
      ORDER BY data_ora DESC
         LIMIT 1;

	IF start_date IS NULL THEN
		start_date = data_inizio;
	END IF;

	RETURN QUERY
		SELECT data_ora,
		       date_trunc('MINUTE', LEAD(data_ora, 1, 'NOW') OVER (order by data_ora) - data_ora),
		       stato
		  FROM (
			SELECT row_number() over() riga,
				GREATEST (data_ora, data_inizio) data_ora,
			       stato
			  FROM (
				SELECT LAG(stato) OVER (ORDER BY data_ora) stato_precedente,
				       data_ora,
				       stato
				  FROM (
					SELECT *
					  FROM storico_commutazioni
				  UNION SELECT *
					  FROM ultima_commutazione
				       ) storico_completo
				 WHERE data_ora BETWEEN start_date AND data_fine
			      ORDER BY data_ora

			  ) storico WHERE stato_precedente IS DISTINCT FROM stato
		 ) storico;
END;$$;


ALTER FUNCTION public.report_commutazioni(data_inizio timestamp without time zone, data_fine timestamp without time zone) OWNER TO smac;

--
-- Name: report_misurazioni(smallint, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION report_misurazioni(pid_sensore smallint, data_ora_inizio timestamp without time zone DEFAULT (now() - '01:00:00'::interval), data_ora_fine timestamp without time zone DEFAULT now()) RETURNS SETOF report_sensore
    LANGUAGE plpgsql
    AS $$DECLARE
   nome_sensore_media VARCHAR;
BEGIN
    -- se null o 0 si tratta della media
    IF pid_sensore IS NULL OR pid_sensore = 0  THEN
        RETURN QUERY
            SELECT date_trunc('minute', misurazioni.data_ora) as tr_data_ora,
                   0::smallint,
                   get_setting('sensore_media_nome'::varchar(64),'Media'::text)::Varchar,
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
-- Name: report_sensori(timestamp without time zone, timestamp without time zone, integer); Type: FUNCTION; Schema: public; Owner: smac
--

CREATE FUNCTION report_sensori(data_ora_inizio timestamp without time zone DEFAULT ((now() - '24:00:00'::interval))::timestamp without time zone, data_ora_fine timestamp without time zone DEFAULT now(), precisione integer DEFAULT 100) RETURNS SETOF report_sensore
    LANGUAGE plpgsql
    AS $$DECLARE
	min_data_ora timestamp without time zone;
	max_data_ora timestamp without time zone;
	delta_sec bigint;
BEGIN

	SELECT min(data_ora), max(data_ora)
	  INTO min_data_ora, max_data_ora
	  FROM misurazioni
	 WHERE data_ora BETWEEN data_ora_inizio
	   AND data_ora_fine;

  delta_sec = date_part('epoch', max_data_ora - min_data_ora)::bigint / precisione;
  IF delta_sec = 0 THEN
    RETURN;
  END IF;

        RETURN QUERY
            SELECT MIN(misurazioni.data_ora) as data_ora,
                   misurazioni.id_sensore,
                   sensori.nome_sensore,
                   AVG(misurazioni.temperatura)::numeric(9,4) temperatura,
                   AVG(misurazioni.umidita)::numeric(9,4) umidita
              FROM misurazioni
        INNER JOIN sensori
                ON (sensori.id_sensore = misurazioni.id_sensore)
             WHERE misurazioni.data_ora BETWEEN data_ora_inizio AND data_ora_fine
          GROUP BY misurazioni.id_sensore,
                   sensori.nome_sensore,
                   date_trunc('seconds', (misurazioni.data_ora - min_data_ora)::interval(0) / delta_sec)
          ORDER BY misurazioni.id_sensore, data_ora;

END;$$;


ALTER FUNCTION public.report_sensori(data_ora_inizio timestamp without time zone, data_ora_fine timestamp without time zone, precisione integer) OWNER TO smac;

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
-- Name: dati_giornalieri; Type: TABLE; Schema: public; Owner: smac; Tablespace:
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


ALTER TABLE public.dati_giornalieri OWNER TO smac;

--
-- Name: dettaglio_programma; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE dettaglio_programma (
    id_programma integer NOT NULL,
    giorno smallint NOT NULL,
    ora time without time zone NOT NULL,
    t_riferimento smallint
);


ALTER TABLE public.dettaglio_programma OWNER TO smac;

--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE driver_sensori_id_driver_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.driver_sensori_id_driver_seq OWNER TO smac;

--
-- Name: driver_sensori; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE driver_sensori (
    id smallint DEFAULT nextval('driver_sensori_id_driver_seq'::regclass) NOT NULL,
    nome character varying(16),
    parametri character varying(64)
);


ALTER TABLE public.driver_sensori OWNER TO smac;

--
-- Name: impostazioni; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE impostazioni (
    nome character varying(128) NOT NULL,
    valore text
);


ALTER TABLE public.impostazioni OWNER TO smac;

--
-- Name: COLUMN impostazioni.nome; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON COLUMN impostazioni.nome IS 'Nome della voce di impostazione';


--
-- Name: COLUMN impostazioni.valore; Type: COMMENT; Schema: public; Owner: smac
--

COMMENT ON COLUMN impostazioni.valore IS 'Valore della voce di impostazione';


--
-- Name: misurazioni; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE misurazioni (
    id_misurazione bigint NOT NULL,
    data_ora timestamp without time zone DEFAULT now() NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4)
);


ALTER TABLE public.misurazioni OWNER TO smac;

--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE; Schema: public; Owner: smac
--

CREATE SEQUENCE misurazioni_id_misurazione_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.misurazioni_id_misurazione_seq OWNER TO smac;

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


ALTER TABLE public.programma_id_programma_seq OWNER TO smac;

--
-- Name: programma_id_programma_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE programma_id_programma_seq OWNED BY programmi.id_programma;


--
-- Name: sensori; Type: TABLE; Schema: public; Owner: smac; Tablespace:
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


ALTER TABLE public.sensori OWNER TO smac;

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


ALTER TABLE public.sensori_id_sensore_seq OWNER TO smac;

--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: smac
--

ALTER SEQUENCE sensori_id_sensore_seq OWNED BY sensori.id_sensore;


--
-- Name: situazione; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE situazione (
    data_ora timestamp without time zone NOT NULL,
    id_sensore smallint NOT NULL,
    temperatura numeric(9,4),
    umidita numeric(9,4),
    tendenza_temperatura numeric(9,4),
    tendenza_umidita numeric(9,4)
);


ALTER TABLE public.situazione OWNER TO smac;

--
-- Name: start_date; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE start_date (
    data_ora timestamp without time zone
);


ALTER TABLE public.start_date OWNER TO smac;

--
-- Name: storico_commutazioni; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE storico_commutazioni (
    data_ora timestamp without time zone DEFAULT now() NOT NULL,
    stato boolean
);


ALTER TABLE public.storico_commutazioni OWNER TO smac;

--
-- Name: ultima_commutazione; Type: TABLE; Schema: public; Owner: smac; Tablespace:
--

CREATE TABLE ultima_commutazione (
    data_ora timestamp without time zone DEFAULT now() NOT NULL,
    stato boolean
);


ALTER TABLE public.ultima_commutazione OWNER TO smac;

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
-- Data for Name: dettaglio_programma; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY dettaglio_programma (id_programma, giorno, ora, t_riferimento) FROM stdin;
1	1	00:00:00	0
1	1	05:00:00	2
1	1	06:00:00	3
1	1	07:00:00	4
1	1	17:00:00	3
1	1	18:00:00	4
1	3	00:00:00	1
1	3	05:00:00	2
1	3	06:00:00	3
1	3	07:00:00	4
1	3	17:00:00	3
1	3	18:00:00	4
1	4	00:00:00	1
1	4	05:00:00	2
1	4	06:00:00	3
1	4	07:00:00	4
1	4	17:00:00	3
1	4	18:00:00	4
1	5	00:00:00	1
1	5	05:00:00	2
1	5	06:00:00	3
1	5	07:00:00	4
1	5	17:00:00	3
1	5	18:00:00	4
1	6	00:00:00	1
1	6	06:00:00	3
1	6	20:30:00	1
1	7	00:00:00	1
1	7	06:00:00	3
1	7	20:30:00	1
1	1	21:00:00	1
1	2	00:00:00	1
1	2	05:00:00	2
1	2	06:00:00	3
1	2	07:00:00	4
1	2	17:00:00	3
1	2	18:00:00	4
1	2	21:00:00	1
1	3	21:00:00	1
1	4	21:00:00	1
1	5	21:00:00	1
1	1	07:45:00	1
1	3	07:45:00	1
1	4	07:45:00	1
1	5	07:45:00	1
1	2	07:45:00	1
\.


--
-- Data for Name: driver_sensori; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY driver_sensori (id, nome, parametri) FROM stdin;
1	DHT11	--sensor=11 --retries=7 --delay_seconds=3
2	DHT22	--sensor=22 --retries=7 --delay_seconds=3
3	SESPS	--server=127.0.0.1
\.


--
-- Name: driver_sensori_id_driver_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('driver_sensori_id_driver_seq', 2, true);


--
-- Data for Name: impostazioni; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY impostazioni (nome, valore) FROM stdin;
programma_spento_nome	Spento
programma_spento_descrizione	Il sistema rimarrà sempre spento, indipendentemente dalle temperature registrate
programma_anticongelamento_nome	Anticongelamento
programma_anticongelamento_descrizione	Il sistema si accenderà solo per evitare il congelamento. Cioè quando la temperatura ambientale scenderà al di sotto di quella rilevata da sensore di anticongelamento
programma_manuale_nome	Manuale
programma_manuale_descrizione	Il sistema proverà a mantenere la temperatura impostata manualmente
programma_anticongelamento_sensore	0
temperatura_anticongelamento	5
programma_manuale_sensore	0
temperatura_manuale	22
rele_gpio_pin_no	24
	0
programma_attuale	1
\.

--
-- Name: misurazioni_id_misurazione_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('misurazioni_id_misurazione_seq', 1, true);


--
-- Name: programma_id_programma_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('programma_id_programma_seq', 1, true);


--
-- Data for Name: programmi; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY programmi (id_programma, nome_programma, descrizione_programma, temperature_rif, sensore_rif) FROM stdin;
1	Settimana standard	Programma per una settimana standard, con fine settimana non lavorativo. Mantiene caldo solo in orari necessari, usando la media dei sensori come riferimento	{18.0000,19.0000,20.0000,21.0000}	0
\.


--
-- Data for Name: sensori; Type: TABLE DATA; Schema: public; Owner: smac
--

COPY sensori (id_sensore, nome_sensore, descrizione, posizione, abilitato, incluso_in_media, id_driver, ultimo_aggiornamento, parametri) FROM stdin;
2	Corridoio	Sensore nel corridio	\N	t	t	1	2016-05-15 16:01:02.954186	--pin=22
1	Tinello	Sensore Tinello	\N	t	t	1	2016-05-15 16:01:02.954186	--pin=4
\.


--
-- Name: sensori_id_sensore_seq; Type: SEQUENCE SET; Schema: public; Owner: smac
--

SELECT pg_catalog.setval('sensori_id_sensore_seq', 2, true);

--
-- Name: dati_giornalieri_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY dati_giornalieri
    ADD CONSTRAINT dati_giornalieri_pkey PRIMARY KEY (data, id_sensore);


--
-- Name: dettaglio_programma_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY dettaglio_programma
    ADD CONSTRAINT dettaglio_programma_pkey PRIMARY KEY (id_programma, giorno, ora);


--
-- Name: driver_sensori_nome_driver_key; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_nome_driver_key UNIQUE (nome);


--
-- Name: driver_sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY driver_sensori
    ADD CONSTRAINT driver_sensori_pkey PRIMARY KEY (id);


--
-- Name: impostazioni_pk; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY impostazioni
    ADD CONSTRAINT impostazioni_pk PRIMARY KEY (nome);


--
-- Name: misurazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT misurazioni_pkey PRIMARY KEY (id_misurazione);


--
-- Name: programma_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT programma_pkey PRIMARY KEY (id_programma);


--
-- Name: sensori_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY sensori
    ADD CONSTRAINT sensori_pkey PRIMARY KEY (id_sensore);


--
-- Name: situazione_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY situazione
    ADD CONSTRAINT situazione_pkey PRIMARY KEY (id_sensore);


--
-- Name: storico_commutazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY storico_commutazioni
    ADD CONSTRAINT storico_commutazioni_pkey PRIMARY KEY (data_ora);


--
-- Name: un_data_sensore; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY misurazioni
    ADD CONSTRAINT un_data_sensore UNIQUE (data_ora, id_sensore);


--
-- Name: un_nome_programma; Type: CONSTRAINT; Schema: public; Owner: smac; Tablespace:
--

ALTER TABLE ONLY programmi
    ADD CONSTRAINT un_nome_programma UNIQUE (nome_programma);


--
-- Name: data_ora_misurazione_asc; Type: INDEX; Schema: public; Owner: smac; Tablespace:
--

CREATE INDEX data_ora_misurazione_asc ON misurazioni USING btree (data_ora);


--
-- Name: un_nome_sensore; Type: INDEX; Schema: public; Owner: smac; Tablespace:
--

CREATE UNIQUE INDEX un_nome_sensore ON sensori USING btree (nome_sensore);


--
-- Name: aggiornamento_configurazione; Type: TRIGGER; Schema: public; Owner: smac
--

CREATE TRIGGER aggiornamento_configurazione AFTER UPDATE ON impostazioni FOR EACH ROW WHEN ((old.valore <> new.valore)) EXECUTE PROCEDURE notifica_modifica_configurazione();


--
-- Name: aggiornamento_situazione; Type: TRIGGER; Schema: public; Owner: smac
--

CREATE TRIGGER aggiornamento_situazione AFTER INSERT ON misurazioni FOR EACH ROW WHEN (((new.temperatura IS NOT NULL) OR (new.umidita IS NOT NULL))) EXECUTE PROCEDURE aggiorna_situazione();


--
-- Name: notifica_variazione_sensori; Type: TRIGGER; Schema: public; Owner: smac
--

CREATE TRIGGER notifica_variazione_sensori AFTER INSERT OR DELETE OR UPDATE ON sensori FOR EACH STATEMENT EXECUTE PROCEDURE notifica_modifica();


--
-- Name: nuova_commutazione; Type: TRIGGER; Schema: public; Owner: smac
--

CREATE TRIGGER nuova_commutazione BEFORE INSERT ON storico_commutazioni FOR EACH ROW EXECUTE PROCEDURE aggiorna_storico_commutazioni();


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
