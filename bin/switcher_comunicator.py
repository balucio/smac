#!/usr/bin/python
#-*- coding: utf8 -*-

import argparse

from switch import Switch
from smac_utils import setup_logger
from logging import getLogger
from sys import exit


if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    cmd_list = ['state', 'reload', 'on', 'off']

    parser.add_argument("command", choices=cmd_list,
                        help="Comando da inviare allo switcher")

    args = parser.parse_args()

    # Setup log file
    setup_logger('switcher_communicator', log_file=None)
    log = getLogger('switcher_communicator')

    try:
        cmd = args.command
        sw = Switch(log)
        res = getattr(sw,  cmd)()
        print(res)
        exit(0)
    except Exception as e:
        print(repr(e))
        exit(1)
