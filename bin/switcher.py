#!/usr/bin/python
#-*- coding: utf8 -*-

import argparse
import time
import RPi.GPIO as GPIO
import signal

from daemon import Daemon
from database import Database
from comunicator import Comunicator
from logging import DEBUG
from os import getpid
from sys import exit
from smac_utils import (
    read_db_config, SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT)


class Switcher(Daemon):

    DEF_LOG_LEVEL = DEBUG

    def run(self):

        # Init GPIO Board
        self.log.debug(
            'Inizializzazione GPIO: revisione %s'
            % (GPIO.RPI_REVISION)
        )

        # Init del ping gipio
        self.pin = self._get_gpio_pin(self._get_valid_pins(GPIO.RPI_REVISION))

        # Registro di reload e uscita
        signal.signal(signal.SIGHUP, self._load_config)
        signal.signal(signal.SIGTERM, self._cleanup)

        # Configuro le pipe di comunicazione
        comm = Comunicator(
            Comunicator.MODE_SERVER, SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT)

        # Modo numerazione pin Broadcom's SoC
        GPIO.setmode(GPIO.BCM)
        # Init del relè
        GPIO.setup(self.pin, GPIO.OUT)
        state = self._set_pin_off(self.pin)

        while True:
            # In ascolto sul canale di comunicazione
            msg = comm.read_message(None)
            cmd = msg[1]
            self.log.debug("Ricevuto comando: %s" % (cmd))

            if cmd == 'ON':

                if cmd != state:
                    self._set_pin_on(self.pin)
                response = 'OK:%s' % (cmd)

            elif cmd == 'OFF':

                if cmd != state:
                    self._set_pin_off(self.pin)
                response = 'OK:%s' % (cmd)

            elif cmd == 'STATUS':
                response = 'OK:%s' % (self._get_pin_status(self.pin, state))

            elif cmd == 'TIMEOUT':
                self.log.info("Timeout in lettura")
                continue
            else:
                response = 'ERROR'

            self.log.debug("Invio risposta: %s" % (response))
            comm.send_message(getpid(), response, timeout=5)

    def _load_config(self, signum, frame):
        self.log.warning(
            "Ricevuto segnale %s frame %s: ricarico configurazione"
            % (signum, frame))
        GPIO.cleanup()
        self.pin = self._get_gpio_pin(self.pins)

    def _cleanup(self, signum, frame):
        self.log.warning(
            "Ricevuto segnale %s frame %s: uscita"
            % (signum, frame))
        GPIO.cleanup()
        exit(0)

    def _set_pin_on(self, pin):
        self.log.debug("Pin: %s impostato in ON" % (pin))
        GPIO.output(pin, GPIO.LOW)
        return GPIO.HIGH

    def _set_pin_off(self, pin):
        self.log.debug("Pin: %s impostato in OFF" % (pin))
        GPIO.output(pin, GPIO.HIGH)
        return GPIO.LOW

    def _get_pin_status(self, pin, raw_state):

        state = 'ON' if raw_state == GPIO.HIGH else 'OFF'
        self.log.debug("Pin: %s stato %s" % (pin, state))
        return state

    def _get_db_connection(self, dbd):
        return Database(dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def _get_gpio_pin(self, pins):
        db = self._get_db_connection(read_db_config())

        #  Ciclo fino a quando non ottengo un pin del GPIO valido
        while True:

            raw = db.query("SELECT get_setting('rele_gpio_pin_no')")
            self.log.debug('Lettura pin GPIO del relè: %s' % (raw))

            if len(raw) == 1:
                pin = 'GPIO{0:02d}'.format(int(raw[0][0]))
                if pin in pins:
                    self.log.info('Uso Pin GPIO %s' % pin)
                    break
                else:
                    self.log.error('Pin GPIO %s impostato non è valido' % pin)
                    #raise ValueError('PIN GPIO % Impostato non è valido' % pin)

            # Tento rilettura tra due minuti
            time.sleep(120)

        return int(pin[-2:])

    def _get_valid_pins(self, revision):

        pins = ['GPIO04', 'GPIO07', 'GPIO08', 'GPIO09', 'GPIO10', 'GPIO11',
                'GPIO17', 'GPIO18', 'GPIO22', 'GPIO23', 'GPIO24']

        if revision == 1:
            pins.extend(['GPIO21'])

        elif revision >= 2:
            pins.extend(['GPIO27'])

            if revision > 2:
                pins.extend(['GPIO05', 'GPIO06', 'GPIO12',
                             'GPIO13', 'GPIO16', 'GPIO19',
                             'GPIO20', 'GPIO21', 'GPIO26'])
        return pins


SWITCHER_LOG = '/opt/smac/log/switcher.log'
SWITCHER_PID = '/var/run/switcher/switcher.pid'

if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "action", choices=['start', 'stop', 'reload'],
        help="Uso start|stop|restart")

    parser.add_argument(
        "--pid", required=False, nargs='?', default=SWITCHER_PID,
        help="PID file del demone")

    parser.add_argument(
        "--log", required=False, nargs='?', default=SWITCHER_LOG,
        help="LOG file")

    args = parser.parse_args()
    daemon = Switcher(args.pid, logfile=args.log)

    if 'start' == args.action:
        daemon.start()
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()
    elif 'reload' == args.action:
        daemon.reload()
