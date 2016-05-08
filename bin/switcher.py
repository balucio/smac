#!/usr/bin/python
#-*- coding: utf8 -*-

import argparse
import time
import RPi.GPIO as GPIO
import signal

from daemon import Daemon
from comunicator import Comunicator
from logging import WARNING
from os import getpid
from sys import exit
from smac_utils import (SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT)


class Switcher(Daemon):

    DEF_LOG_LEVEL = WARNING

    def __init__(
        self, pidfile, stdin='/dev/null', stdout='/dev/null',
        stderr='/dev/null', logfile='/dev/null', invert_state=False
    ):
        super(Switcher, self).__init__(pidfile, stdin, stdout, stderr, logfile)
        self.invert_state = invert_state

    def run(self):

        # Configuro le pipe di comunicazione
        self.comm = Comunicator(
            Comunicator.MODE_SERVER, SWITCHER_PIPE_IN,
            SWITCHER_PIPE_OUT, self.log)

        if self.invert_state:

            self.STATE_ON, self.STATE_OFF = GPIO.LOW, GPIO.HIGH
            self.log.debug(
                'Stato ON -> GPIO.LOW (%s), Stato OFF -> GPIO.HIGH (%s)',
                GPIO.LOW, GPIO.HIGH)
        else:

            self.STATE_ON, self.STATE_OFF = GPIO.HIGH, GPIO.LOW
            self.log.debug(
                'Stato ON -> GPIO.HIGH (%s), Stato OFF -> GPIO.LOW (%s)',
                GPIO.HIGH, GPIO.LOW)

        # Init GPIO Board
        self.log.debug(
            'Inizializzazione GPIO: revisione %s', GPIO.RPI_REVISION)

        # Registro funzioni reload e uscita
        signal.signal(signal.SIGHUP, self._load_config)
        signal.signal(signal.SIGTERM, self._cleanup)

        state = self.STATE_OFF
        self.reset_state = True
        self.pin = None

        while True:

            if self.reset_state:
                # In attesa di configurazione pin GPIO
                self.pin = self._wait_for_gpio_pin()
                state = self.STATE_OFF
                self.reset_state = False

            # Attendo un nuovo comando
            msg = self.comm.read_message(None)
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
                self.log.warning("Ricarico configurazione...")
                self.reset_state = True
                response = "OK:RELOADING"
                GPIO.cleanup()

            elif cmd == 'TIMEOUT':
                self.log.info("Timeout in lettura")
                continue

            else:
                response = 'ERROR'

            self.log.debug("Invio risposta: %s", response)
            # Attendo qualche istante per sincronizzare l'actuator
            time.sleep(0.5)
            self.comm.send_message(getpid(), response, timeout=15)

    def _load_config(self, signum, frame):
        self.log.warning(
            "Ricevuto segnale %s frame %s: ricarico configurazione",
            signum, frame)

        GPIO.cleanup()
        self.reset_state = True

    def _cleanup(self, signum, frame):

        self.log.warning(
            "Ricevuto segnale %s frame %s: uscita", signum, frame)
        GPIO.setwarnings(False)
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

    def _wait_for_gpio_pin(self):

        pin = None

        self.log.info("Attendo configurazione pin GPIO")

        while pin is None:
            msg = self.comm.read_message(None)
            gpio = msg[1]

            if 'GPIO' in gpio:
                try:
                    pin = int(gpio[-2:])
                    # Modo numerazione pin: Broadcom's SoC
                    GPIO.setmode(GPIO.BCM)
                    # Init del relè default off
                    GPIO.setup(pin, GPIO.OUT, initial=self.STATE_OFF)
                    self.log.info('Configuro GPIO %s per Relè', pin)
                    self.comm.send_message(getpid(), 'OK:CONFIGURED')

                except Exception as e:
                    pin = None
                    self.log.error(
                        'Impossibile inizializzare il pin GPIO %s', repr(e))
            else:
                self.comm.send_message(getpid(), 'ERROR', timeout=5)
                self.log.warning('Ignorato messaggio %s', msg)

        return pin

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
