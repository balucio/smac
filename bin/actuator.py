#!/usr/bin/python
#-*- coding: utf8 -*-

import argparse
import smac_utils
import datetime

from daemon import Daemon
from database import Database
from switch import Switch
from logging import INFO
from decimal import Decimal
from time import sleep


class Actuator(Daemon):

    SLEEP_TIME = 180            # controllo standard 180 sec, 3 minuti
    DEF_LOG_LEVEL = INFO

    TEMP_THRESHOLD = 0.5        # Grado soglia di innesco cambiamento stato
    TEMP_MAXTHRESHOLD = 1.0     # Soglia massima variazione sleep per rating
    TIME_THRESHOLD = 7200       # 2 ore

    SENS_DATA_THR = 1800        # soglia di validità dati sensori.

    def run(self):

        self.db = self._get_db_connection(
            smac_utils.read_db_config()
        )
        # inizializzo lo swich passando il log attuale
        self.sw = Switch(self.log)

        # inizializzo lo switcher inviandogli la configurazione del pi
        self.log.info('Invio configurazione allo switcher')
        # Lo switcher non configurato ignora ogni comando. Tuttavia
        # nel caso fosse già configurato ignorerebbe il set_gipio_pin
        self.sw.reload()
        while not self.sw.set_gpio_pin(self._get_gpio_pin()):
            self.log.error('Impossible configurare lo switcher')
            sleep(30)

        delay_check = 0

        self.db.set_notification(Database.EVT_ALTER_RELE_PIN)
        self.db.set_notification(Database.EVT_ALTER_PROGRAM)

        while True:

            # inizio transazione
            self.db.begin_transaction()

            # Ottengo pid e temperatura di rifemento
            (pid, trif) = self._get_current_schedule()

            # commit e chiudo transazione
            self.db.commit()
            self.db.end_transaction()

            # se pid -1 significa sistema spento imposto una temperatura
            # fittizia (-100) per costringere il sistema a spegnersi
            trif = Decimal(-100) if pid == -1 else trif
            sensordata = self._get_sensor_data()

            if not sensordata:
                self.log.error('Impossibile ottenere stato dei sensori')
                delay_check = self.SLEEP_TIME * 2
                self.sw.off()

            elif not self._is_actual_data(sensordata['lastup'],
                                          self.TIME_THRESHOLD):
                self.log.error(
                    'Dati sensore non aggiornati (%s)', sensordata['lastup'])
                delay_check = self.SLEEP_TIME
                self.sw.off()

            else:
                self.log.debug(
                    'Ultimo aggiornamento dati %s', sensordata['lastup'])
                rating = self._get_temp_rating(
                    sensordata['temp'], sensordata['tavg'], sensordata['tfor']
                )

                # Imposto lo stato del sistema in base ai parametri rilevati
                delay_check = self._set_system_state(
                    trif, sensordata['temp'], rating
                )

            # attendo eventi sul db fino a delay_check
            if self.db.wait_notification(delay_check):
                self._check_db_events()

    def _get_db_connection(self, dbd):
        return Database(dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def _check_db_events(self):

        self.log.debug('Verifico notifiche da Database')

        # notify.pid, notify.channel, notify.payload
        notify = self.db.get_notification()

        while notify:

            self.log.info(
                'Ricevuta notifica pid %s, canale %s, contenuto: %s',
                notify.pid, notify.channel, notify.payload
            )

            if notify.channel == Database.EVT_ALTER_PROGRAM:
                # risvegliato dal cambio programma
                # ignoro tutto, perchè in ogni caso rileggo
                pass
            elif notify.channel == Database.EVT_ALTER_RELE_PIN:
                # invio nuove impostazioni allo switcher
                while True:

                    if self.sw.reload():
                        sleep(0.5)      # sync con switcher
                        if self.sw.set_gpio_pin(notify.payload):
                            break
                    sleep(10)

            notify = self.db.get_notification()

    def _get_gpio_pin(self):

        pin = None
        while pin is None:

            try:
                str_pin = self.db.get_setting(Database.DB_SET_PIN_RELE, None)
                self.log.debug('Valore Database %s', str_pin)
                pin = int(str_pin)
                self.log.info('Uso Pin GPIO %s', pin)

            except Exception as e:
                    self.log.error('Errore lettura pin GPIO Relè', repr(e))
                    raise
        return pin

    def _get_current_schedule(self):

        # La stored function programmazioni() restituisce la programmazione
        # del programma corrente quando richiamata senza parametri
        schedule = self.db.query(
            "SELECT id_programma, t_rif_val FROM programmazioni()"
            " WHERE current_time > ora ORDER BY ora DESC LIMIT 1")
        self.log.debug('Lettura programmazione attuale: %s', schedule)
        return schedule[0] if schedule else []

    def _is_actual_data(self, capture_time, thr):

        delta = datetime.datetime.now() - capture_time

        delta_sec = abs(delta.total_seconds())

        return False if delta_sec > thr else True

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
                'id':     d[0],  'name':    d[2],  'temp':   d[3],
                'tmin':   d[4],  'tavg':    d[5],  'tmax':   d[6],
                'tfor':   d[7],  'humd':    d[8],  'hmin':   d[9],
                'havg':   d[10], 'hmax':    d[11], 'hfor':   d[12],
                'lastup': d[13], 'lastfor': d[14]
            }

        return sdata

    # Rating indice di stabilità della temperatura
    # 2 in salita, 1 probabile salita, 0.5 salita incerta
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
            'Rating: %s - T° mis: %s - T° media: %s - T° prevista %s',
            rating, treal, tavg, tfor)
        return rating

    def _set_system_state(self, reference, temperature, rating):

        next_check = self.SLEEP_TIME
        deltat = abs(reference - temperature)
        stato_attuale = self.sw.state()
        nuovo_stato = stato_attuale

        self.log.debug('Stato Sistema: %s' % (stato_attuale))

        # Commuto il sistema in on/off se si supera la soglia minima
        if deltat >= self.TEMP_THRESHOLD:

            nuovo_stato = (
                Switch.ST_ON if reference > temperature else Switch.ST_OFF
            )

            self.log.debug(
                'Rilevazione: T Ril %.2f, T Rif %.2f - SUPERATA Soglia %s',
                temperature, reference, self.TEMP_THRESHOLD
            )

        else:

            self.log.debug(
                'Rilevazione: T Ril %.2f, T Rif %.2f - ENTRO Soglia %s',
                temperature, reference, self.TEMP_THRESHOLD
            )

            # Nel caso lo stato attuale sia sconosciuto forzo il sistema
            # ad avere uno stato consistente
            if stato_attuale == Switch.ST_UNKNOW:
                nuovo_stato = (
                    Switch.ST_ON if reference > temperature else Switch.ST_OFF
                )
                self.log.warning('Stato sconosciuto: Forzo Commutazione')

        res = True

        # Inserisco stato caldaia a database
        self.db.query(
            'INSERT INTO storico_commutazioni(stato) VALUES(%s)',
            [None if nuovo_stato is Switch.ST_UNKNOW
             else nuovo_stato == Switch.ST_ON]
        )

        if nuovo_stato != stato_attuale:

            self.log.info(
                'Commutazione: DA %s - A %s',
                stato_attuale, nuovo_stato)

            res = (self.sw.on() if nuovo_stato == Switch.ST_ON
                   else self.sw.off())

            if not res:

                next_check = self.SLEEP_TIME // 3
                self.log.error(
                    'Impossibile commutare il sistema in %s'
                    ' Prossmo controllo tra %s secondi',
                    nuovo_stato, next_check
                )
        else:
            self.log.debug(
                'Sistema in stato %s - Nessuna commutazione', nuovo_stato)

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

            self.log.debug(
                "T Ril %.2f entro soglia massima %s. Fisso prossimo controllo "
                "tra %s sec in base IST (indice stabilità temperatura) %s",
                temperature, self.TEMP_MAXTHRESHOLD, next_check, rating)

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
