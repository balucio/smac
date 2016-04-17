#!/usr/bin/python
#-*- coding: utf8 -*-


from switchercom import SwitcherCom
from logging import getLogger
from smac_utils import (
    second_since_midnight,
    second_to_time,
    epoch_timestamp,
    BASE_LOG,
    setup_logger
)


class Switch(object):

    ST_ON = 'ON'
    ST_OFF = 'OFF'
    ST_UNKNOW = 'UNKNOW'

    time_on = 0           # secondi in cui il sistema rimane acceso
    time_off = 0          # secondi in cui il sistema rimane spento
    time_err = 0          # secondi in cui lo stato è sconosciuto
    time_tot = 0          # secondi di monitoraggio totale
    time_init = 0         # tempo di inizializzazione
    time_day = 0          # mantiene il cambio giorno

    _log = None

    def __init__(self):
        self.swc = SwitcherCom()
        setup_logger(self.__class__.__name__, BASE_LOG + 'switch.log')
        self._log = getLogger(self.__class__.__name__)

        self._log.info('Inizializzazione switch')

        self.time_init = epoch_timestamp()
        self.time_day = second_since_midnight()

    def state(self):

        state = self._send_command(SwitcherCom.cmd_status)

        if state == SwitcherCom.state_on:
            return self.ON
        elif state == SwitcherCom.state_off:
            return self.OFF
        else:
            return self.ST_UNKNOW

    def on(self):

        state = self._send_command(SwitcherCom.cmd_on)
        self._update_timers(state)
        return state == SwitcherCom.state_on

    def off(self):
        state = self._send_command(SwitcherCom.cmd_off)
        self._update_timers(state)
        return state == SwitcherCom.state_off

    def _send_command(self, command):

        resp = self.swc.send_command(command)

        if not self.swc.is_response_ok(resp):
            self._log.warning(
                "Errore invio comando %s, ricevuto %s " % (command, resp)
            )

            return SwitcherCom.state_unknow

        return self.swc.get_response_msg(resp)

    def _update_timers(self, state):

        delta = epoch_timestamp() - self.time_init
        self.time_tot += delta
        self.time_day += delta

        # Log al cambio di giorno
        mid_sec = second_since_midnight()
        if self.time_day > mid_sec:

            self.time_day = mid_sec

            self._log.info(
                "Tempo sistema acceso %s"
                % (second_to_time(self.time_on))
            )

            self._log.info(
                "Tempo sistema spento %s"
                % (second_to_time(self.time_off))
            )

            self._log.warning(
                "Tempo sistema in stato indeterminato %s"
                % (second_to_time(self.time_err))
            )

        if state == SwitcherCom.state_unknow:
            self.time_err += delta
        elif state == SwitcherCom.state_on:
            self.time_on += delta
        elif state == SwitcherCom.state_off:
            self.time_err += delta
