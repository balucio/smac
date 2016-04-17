#!/usr/bin/python
#-*- coding: utf8 -*-

import os

from comunicator import Comunicator
from smac_utils import SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT


class SwitcherCom(object):

    cmd_off = 'OFF'
    cmd_on = 'ON'
    cmd_status = 'STATUS'

    state_on = 'ON'
    state_off = 'OFF'
    state_unknow = None

    resp_error = 'ERROR'
    resp_timeout = 'TIMEOUT'
    resp_ok = 'OK'

    def __init__(self):
        self.comm = Comunicator(
            Comunicator.MODE_CLIENT, SWITCHER_PIPE_IN, SWITCHER_PIPE_OUT
        )

    def send_command(self, command):

        response = None

        if self.comm.send_message(os.getpid(), command):
            response = self.com.read_message()
        else:
            return self.resp_error

        return response[1]

    def is_response_ok(self, response):
        return response[0:2] == self.resp_ok

    def get_response_msg(self, response):
        return response[3:]
