#!/usr/bin/python
#-*- coding: utf8 -*-

import time
import subprocess
import argparse
import json

from daemon import Daemon
from database import Database
from datetime import datetime
from smac_utils import read_db_config
from logging import INFO,DEBUG,CRITICAL


class Collector(Daemon):

    SLEEP_TIME = 60
    DEF_LOG_LEVEL = DEBUG #DEBUG

    DRIVERS_BASE_PATH = '/opt/smac/bin/'

    DRIVERS_COMMANDS = {
        'DHT11': 'dhtxx.py',
        'DHT22': 'dhtxx.py',
        'SESPS': 'sesps.py'
    }

    def run(self):

        self.db = self._get_db_connection(read_db_config())

        self.sensors = self.sensors = self._get_sensor_list()

        # Ascolto per notifiche sulla tabella sensori
        self.db.set_notification('sensori')

        while True:

            # inizio transazione e blocco la tabella sensori
            self.db.begin_transaction()
            self.db.lock_table('sensori')

            # Ricarico la configuraizone se ho ricevuto notifiche
            if self._needs_reload():
                self.sensors = self.sensors = self._get_sensor_list()

            detections = []
            self.log.debug('Elaboro elenco sensori')
            # per ciascun sensore ricavo i dati e li scrivo a database
            # id_sensore, driver_params, driver, driver_low_level_param
            for sid, spars, driver, driverpars in self.sensors:

                param = driverpars.split(' ') + spars.split(' ')
                driver = driver.upper()

                if driver in self.DRIVERS_COMMANDS:

                    try:
                        exec_data = self._driver_exec(self.DRIVERS_COMMANDS[driver], param)
                        measuredata = self._decode_driver_result(sid, driver, exec_data)

                    except Exception as e:
                       self.log.error(
                           "Impossibile decodificare l'output del driver: %s", repr(e))
                       measuredata = None

                if measuredata is not None:
                    if isinstance(measuredata, dict):
                        detections.append(measuredata)
                    else:
                        detections.extend(measuredata)

            if len(detections):
                err = self._write_sensor_data(detections)

            # Eseguo il commit e rilascio i lock sul sensori
            self.db.commit() if not err else self.db.rollback()

            self.db.end_transaction()
            # attendo
            time.sleep(self.SLEEP_TIME)

    def _get_db_connection(self, dbd):
        return Database(dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def _get_sensor_list(self):

        self.log.debug('Lettura elenco sensori')
        slist = self.db.query(
            "SELECT id, parametri, nome_driver, parametri_driver"
            " FROM elenco_sensori(true)")
        # elimino la media che è sempre il primo
        slist.pop(0)
        return slist

    def _write_sensor_data(self, measures):

        query = """
            INSERT INTO misurazioni (
                data_ora, id_sensore, temperatura, umidita
            )
            VALUES(
                %(date_time)s, %(sensor_id)s, %(temperatura)s, %(umidita)s
            )
        """

        error = False
        try:
            self.db.insert_many(query, measures)
            self.log.debug('Misurazioni dei sensori salvate sul database')

        except Exception as e:
            self.log.error(
                'Impossibile scrivere le misurazioni a database : %s', repr(e))
            error = True

        return error

    def _driver_exec(self, command, parameters):

        cmnd = ['sudo', self.DRIVERS_BASE_PATH + command] + parameters
        try:
            pipes = subprocess.Popen(cmnd, stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE)
            std_out, std_err = pipes.communicate()
            code = pipes.returncode
        except Exception as e:
            code = 127
            std_err = repr(e)

        if code != 0:
            msg = std_err.strip()
        else:
            msg = std_out.strip()

        return (code, msg)

    def _needs_reload(self):

        self.log.debug('Verifico eventuali notifiche')
        self.db.poll_notification()
        needs_reload = False

        # notify.pid, notify.channel, notify.payload
        notify = self.db.get_notification()
        while notify:
            self.log.info(
                'Ricevuta notifica pid %s, canale %s, contenuto: %s',
                notify.pid, notify. channel, notify.payload
            )
            needs_reload = True
            notify = self.db.get_notification()

        return needs_reload

    def _decode_driver_result(self, sid, driver, output):

        if output[0] != 0:

            self.log.error(
                "Errore nell'esecuzione del driver %s sul sensore %s: %s",
                driver, sid, output[1]
            )

        elif driver == 'DHT11' or driver == 'DHT22':

            (temperatura, umidita) = output[1].split(' ')
            self.log.info(
                "Sensore %s: temperatura %s, umidità %s",
                sid, temperatura, umidita
            )
            return {
                'sensor_id': sid,
                'date_time': datetime.today(),
                'temperatura': temperatura,
                'umidita': umidita
            }

        elif driver == 'SESPS' :
            rsamples = json.loads(output[1])
            self.log.info("Sensore %s: %s", sid, output[1])
            samples = []
            for sample in rsamples:
                samples.append({
                    'sensor_id': sid,
                    'date_time': sample['date_time'],
                    'temperatura': sample['temperatura'],
                    'umidita': sample['umidita']
                })
            return samples
        else:
            self.log.error("Driver %s sconosciuto", driver)

        return None

COLLECTOR_LOG = '/opt/smac/log/collector.log'
COLLECTOR_PID = '/var/run/collector/collector.pid'

if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "action", choices=['start', 'stop', 'reload'],
        help="Uso start|stop|restart")

    parser.add_argument(
        "--pid", required=False, nargs='?', default=COLLECTOR_PID,
        help="PID file del demone")

    parser.add_argument(
        "--log", required=False, nargs='?', default=COLLECTOR_LOG,
        help="LOG file")

    args = parser.parse_args()

    daemon = Collector(args.pid, logfile=args.log)

    if 'start' == args.action:
        daemon.start()
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()
