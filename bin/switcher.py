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
from os import (getpid, kill)
from sys import exit
from smac_utils import (
    read_db_config, SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT)


class Switcher(Daemon):

    DEF_LOG_LEVEL = DEBUG

    def __init__(self, pidfile, stdin='/dev/null', stdout='/dev/null',
                 stderr='/dev/null', logfile='/dev/null', invert_state=False):

        super(Switcher, self).__init__(pidfile, stdin, stdout, stderr, logfile)

        self.db = self._get_db_connection(read_db_config())

        if invert_state:

            self.STATE_ON, self.STATE_OFF = GPIO.LOW, GPIO.HIGH
            self.log.debug(
                'Stato ON -> GPIO.LOW (%s), Stato OFF -> GPIO.HIGH (%s)',
                GPIO.LOW, GPIO.HIGH)
        else:

            self.STATE_ON, self.STATE_OFF = GPIO.HIGH, GPIO.LOW
            self.log.debug(
                'Stato ON -> GPIO.HIGH (%s), Stato OFF -> GPIO.LOW (%s)',
                GPIO.HIGH, GPIO.LOW)

    def run(self):

        # Init GPIO Board
        self.log.debug(
            'Inizializzazione GPIO: revisione %s', GPIO.RPI_REVISION)

        # Registro funzioni reload e uscita
        signal.signal(signal.SIGHUP, self._load_config)
        signal.signal(signal.SIGTERM, self._cleanup)

        # Configuro le pipe di comunicazione
        comm = Comunicator(
            Comunicator.MODE_SERVER, SWITCHER_PIPE_IN,
            SWITCHER_PIPE_OUT, self.log)

        self.reset_state = True

        while True:

            # Inizializzo la prima volta e al cambio configurazione
            if self.reset_state:
                self.pin = self._init_gpio_state(self.STATE_OFF)
                state = self.STATE_OFF
                self.reset_state = False

            # In ascolto sul canale di comunicazione
            msg = comm.read_message(None)
            cmd = msg[1]
            self.log.debug("Ricevuto comando: %s", cmd)

            if cmd == 'ON' or cmd == 'OFF':

                response = 'OK:%s' % (cmd)
                res = True

                if cmd == 'ON' and state != self.STATE_ON:
                    res = self._set_pin_on(self.pin)

                elif cmd == 'OFF' and state != self.STATE_OFF:
                    res = self._set_pin_off(self.pin)

                if not res:
                    response = "ERROR"
                else:
                    state = self.STATE_ON if cmd == 'ON' else self.STATE_OFF

            elif cmd == 'STATUS':
                response = 'OK:%s' % (self._get_pin_status(self.pin, state))

            elif cmd == 'RELOAD':
                kill(getpid(), signal.SIGHUP)
                self.log.warning("RIPARTO")
                response = 'OK:RELOADED'

            elif cmd == 'TIMEOUT':
                self.log.info("Timeout in lettura")
                continue
            else:
                response = 'ERROR'

            self.log.debug("Invio risposta: %s", response)
            # Aspetto che l'actuator si metta in read sulla pipe
            time.sleep(0.5)
            comm.send_message(getpid(), response, timeout=15)

    def _load_config(self, signum, frame):
        self.log.warning(
            "Ricevuto segnale %s frame %s: ricarico configurazione",
            signum, frame)

        GPIO.cleanup()
        self.reset_state = True

    def _init_gpio_state(self, state):
        # Modo numerazione pin: Broadcom's SoC
        GPIO.setmode(GPIO.BCM)

        # Init del ping gipio
        pin = self._get_gpio_pin(self._get_valid_pins(GPIO.RPI_REVISION))

        # Init del relè default off
        GPIO.setup(pin, GPIO.OUT, initial=state)

        return pin

    def _cleanup(self, signum, frame):
        self.log.warning(
            "Ricevuto segnale %s frame %s: uscita", signum, frame)
        GPIO.cleanup()
        exit(0)

    def _set_pin_on(self, pin):
        return self._set_pin_state(pin, self.STATE_ON)

    def _set_pin_off(self, pin):
        return self._set_pin_state(pin, self.STATE_OFF)

    def _set_pin_state(self, pin, state):

        stato_raw = 'HIGH' if state == GPIO.HIGH else 'LOW'

        try:
            GPIO.output(pin, state)
            self.log.debug("Pin: %s impostato in %s", pin, stato_raw)
            ret = True

        except Exception as e:
            self.log.error(
                "Impossibile commutare pin %s in %s: %s",
                pin, stato_raw, repr(e))
            ret = False

        return ret

    def _get_pin_status(self, pin, raw_state):

        state = 'ON' if raw_state == self.STATE_ON else 'OFF'
        self.log.debug("Pin: %s stato %s", pin, state)
        return state

    def _get_db_connection(self, dbd):
        return Database(dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def _get_gpio_pin(self, pins):

        #  Ciclo fino a quando non ottengo un pin del GPIO valido
        while True:

            raw = self.db.query("SELECT get_setting('rele_gpio_pin_no')")
            self.log.debug('Lettura pin GPIO del relè: %s', raw)

            if len(raw) == 1:
                pin = 'GPIO{0:02d}'.format(int(raw[0][0]))
                if pin in pins:
                    self.log.info('Uso Pin GPIO %s', pin)
                    break
                else:
                    self.log.error('Pin GPIO %s impostato non è valido', pin)
                    #raise ValueError('PIN GPIO % non è valido' % pin)

            # Tento rilettura tra due minuti
            time.sleep(240)

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

    parser.add_argument("--invert-state", action='store_true')

    parser.add_argument(
        "--log", required=False, nargs='?', default=SWITCHER_LOG,
        help="LOG file")

    args = parser.parse_args()
    daemon = Switcher(
        args.pid, logfile=args.log, invert_state=args.invert_state)

    if 'start' == args.action:
        daemon.start()
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()
    elif 'reload' == args.action:
        daemon.reload()
