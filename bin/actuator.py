#!/usr/bin/python
#-*- coding: utf8 -*-

import time
import argparse
import smac_utils

from daemon import Daemon
from database import Database
from switch import Switch
from logging import INFO


class Actuator(Daemon):

    SLEEP_TIME = 180            # controllo standard 3 minuti
    DEF_LOG_LEVEL = INFO

    TEMP_THRESHOLD = 0.5        # Grado soglia di innesco cambiamento stato
    TEMP_MAXTHRESHOLD = 1.0     # Soglia massima variazione sleep per rating
    TIME_THRESHOLD = 7200       # 2 ore

    def run(self):

        self.db = self._get_db_connection(
            smac_utils.read_db_config()
        )
        self.sw = Switch()

        delay_check = 0

        while True:

            # inizio transazione
            self.db.begin_transaction()

            # Ottengo pid e temperatura di rifemento
            (pid, trif) = self._get_current_schedule()

            # commit e chiudo transazione
            self.db.commit()
            self.db.end_transaction()

            # se pid -1 significa sistema spento imposto una temperatura
            # fittizia per costringere il sistema a spegnersi
            trif = -100 if pid == -1 else trif
            sensordata = self._get_sensor_data()

            if not sensordata:
                self.log.error('Impossibile ottenere stato dei sensori')
                continue

            rating = self._get_temp_rating(
                sensordata['temp'], sensordata['tavg'], sensordata['tfor']
            )

            # Imposto lo stato del sistema in base ai parametri rilevati
            delay_check = self._set_system_state(
                trif, sensordata['temp'], rating
            )

            # attendo
            time.sleep(delay_check)

    def _get_db_connection(self, dbd):
        return Database(dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def _get_current_schedule(self):

        schedule = self.db.query(
            "SELECT id_programma, t_rif_val FROM programmazioni()"
            " WHERE current_time > ora ORDER BY ora DESC LIMIT 1")
        self.log.debug('Lettura programmazione attuale: %s' % (schedule))
        return schedule[0] if schedule else []

    def _get_sensor_data(self):

        rawdata = self.db.query(
            "SELECT * FROM dati_sensore"
            "((SELECT sensore_rif FROM dati_programma()))"
        )
        self.log.debug('Lettura dati sensore di riferimento: %s', (rawdata))
        sdata = {}

        if rawdata:
            d = rawdata.pop()
            sdata = {
                'id':     d[0],
                'name':   d[2],
                'temp':   d[3],
                'tmin':   d[4],
                'tavg':   d[5],
                'tmax':   d[6],
                'tfor':   d[7],
                'humd':   d[8],
                'hmin':   d[9],
                'havg':   d[10],
                'hmax':   d[11],
                'hfor':   d[12],
                'lastup':  d[13],
                'lastfor': d[14]
            }
        return sdata

    # Rating indice di stabilità della temperatura
    # 2 in salita, 1 probaile salita, 0.5 salita incerta
    # -2 in discesa, -1 probabile discesa, -0.5 discesa incerta
    def _get_temp_rating(self, treal, tavg, tfor):

        t_min = min(treal, tavg, tfor)
        t_max = max(treal, tavg, tfor)

        if t_min == treal:
            rating = 2.0 if tfor == t_max else 1.5
        elif t_min == tavg:
            rating = 1.0 if tfor == t_max else -1.0
        elif t_min == tfor:
            rating = -1.5 if tavg == t_max else -2.0

        self.log.debug(
            'Ottenuto valore % di rating per temperature:'
            ' misurata %s, media %s, prevista %',
            (rating, treal, tavg, tfor))
        return rating

    def _set_system_state(self, reference, temperature, rating):

        next_check = self.SLEEP_TIME
        deltat = abs(reference - temperature)
        stato_attuale = self.sw.state()
        nuovo_stato = stato_attuale

        self.log.info('Sistema attualmente in stato %s' % (stato_attuale))

        # Commuto il sistema in on/off se si supera la soglia minima
        if deltat >= self.TEMP_THRESHOLD:

            self.log.info(
                'Superata soglia %s tra Temp rilevata %s e Temp riferimento %s'
                % (self.TEMP_THRESHOLD, temperature, reference)
            )

            nuovo_stato = (
                Switch.ST_ON if reference > temperature else Switch.ST_OFF
            )

            self.log.info('Verifico stato %s del sitema' % (nuovo_stato))

        else:

            # Nel caso lo stato attuale sia sconosciuto forzo il sistema
            # ad avere uno stato consistente
            if stato_attuale != Switch.ST_UNKNOW:
                nuovo_stato = (
                    Switch.ST_ON if reference > temperature else Switch.ST_OFF
                )

            self.log.info(
                'Temperatura rilevata %s entro la soglia riferimento %t'
                % (temperature, reference)
            )

        res = True

        if nuovo_stato != stato_attuale:

            self.log.info(
                'Commuto sistema dallo stato %s allo stato %s'
                % (stato_attuale, nuovo_stato)
            )

            res = (self.sw.on() if nuovo_stato == Switch.ST_ON
                   else self.sw.off())

            if not res:

                next_check = self.SLEEP_TIME // 3
                self.log.error(
                    'Impossibile commutare il sitema allo stato %s'
                    ' il prossimo controllo sarà eseguito tra %s secondi'
                    % (nuovo_stato, next_check)
                )

        if res and deltat <= self.TEMP_MAXTHRESHOLD:

            if nuovo_stato == Switch.ST_ON:
                next_check = (
                    (self.SLEEP_TIME // rating) if rating > 0
                    else (self.SLEEP_TIME * abs(rating))
                )
            else:
                next_check = (
                    (self.SLEEP_TIME * rating) if rating > 0
                    else (self.SLEEP_TIME // abs(rating)))

            self.log.info(
                "Temperatura rilevata %s entro soglia minima. "
                "Prossimo intervallo di controllo %s stabilito "
                " in base all'indice di stabilità %s delle previsioni"
                % (temperature, next_check, rating))

        return next_check


ACTUATOR_LOG = '/opt/smac/log/actuator.log'
ACTUATOR_PID = '/var/run/actuator/actuator.pid'

if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "action", choices=['start', 'stop', 'reload'],
        help="Uso start|stop|restart")

    parser.add_argument(
        "--pid", required=False, nargs='?', default=ACTUATOR_PID,
        help="PID file del demone")

    parser.add_argument(
        "--log", required=False, nargs='?', default=ACTUATOR_LOG,
        help="LOG file")

    args = parser.parse_args()
    daemon = Actuator(args.pid, logfile=args.log)

    if 'start' == args.action:
        daemon.start()
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()