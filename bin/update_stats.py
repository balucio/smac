#!/usr/bin/python
#-*- coding: utf8 -*-

import argparse
import traceback
from datetime import timedelta
from smac_utils import (read_db_config, BASE_LOG, setup_logger)
from logging import (getLogger, INFO)
from sys import exit
from database import Database


class UpdateStats(object):

    def __init__(self, log):
        self.log = log
        dbd = read_db_config()
        self.db = Database(
            dbd['host'], dbd['user'], dbd['pass'], dbd['schema'])

    def updateStats(self, dates):

        query = "SELECT aggiorna_dati_giornalieri(%s::smallint, %s)"

        error = False
        try:
            self.db.insert_many(query, dates)

        except Exception as e:
            self.log.error(
                'Impossibile aggiornare le statistiche : %s', repr(e))
            error = True

        return error

    def getDates(self, past_days=2):

        query = """
            SELECT DISTINCT
                id_sensore,
                data_ora::date
            FROM
                misurazioni
            WHERE
                data_ora > NOW() - %(days)s
            ORDER BY
                data_ora, id_sensore
        """

        return self.db.query(query, {'days': timedelta(days=past_days)})


if __name__ == "__main__":

    #def_log_file = BASE_LOG + 'update_stats.log'
    def_log_file = '/dev/stout'

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--days", required=False, nargs='?', default=2,
        help="Numero di giorni a partire dalla data di oggi da elaborare")

    parser.add_argument(
        "--log", required=False, nargs='?',
        default='/dev/stdout', help="LOG file")

    args = parser.parse_args()

    # Setup log file
    setup_logger('update_stats', args.log, INFO)
    log = getLogger('update_stats')

    st = UpdateStats(log=log)
    try:
        dates = st.getDates(args.days)
        exit(0 if st.updateStats(dates) else 1)
    except Exception as err:
        log.error("Impossibile aggiornare statistiche")
        log.error(traceback.format_exc())
        exit(1)
