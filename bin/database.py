#!/usr/bin/python
#-*- coding: utf8 -*-

import psycopg2

from select import select


class Database(object):

    WATCHDOG_TIMEOUT = 300

    # Eventi
    EVT_ALTER_RELE_PIN = 'rele_gpio_pin_no'  # modifica pin GPIO del rele
    EVT_ALTER_PROGRAM = 'programma_attuale'  # modifica programma attuale
    EVT_ALTER_SENSOR = 'sensori'             # modifica dati sensori

    # Impostazioni
    DB_SET_PIN_RELE = 'rele_gpio_pin_no'

    _db_connection = None
    _db_cur = None

    def __init__(self, host, user, pwd, db):

        self.host = host
        self.user = user
        self.pwd = pwd
        self.db = db
        self.make_connection()

    def query(self, query, params=None):

        self._db_cur.execute(query, params)

        # Hack cerco di capire se è una SELECT o INSERT/UPDATE
        try:
            res = self._db_cur.fetchall()
        except:
            res = self._db_cur.rowcount

        return res

    def lock_table(self, table, lock_mode='ROW EXCLUSIVE'):
        self._db_cur.execute('LOCK %s IN %s MODE' % (table, lock_mode))

    def insert_many(self, query, values):
        self._db_cur.executemany(query, values)

    def get_setting(self, name, default):

        try:
            self._db_cur.execute('SELECT get_setting(%s, %s)', (name, default))
            result = self._db_cur.fetchone()
            return result[0]
        except:
            return default

    def get_query(self):
        return self._db_cur.query

    def set_notification(self, notification):
        self._db_cur.execute('LISTEN ' + notification)

    # Polling per messaggi con timeout / bloccante
    def wait_notification(self, timeout=None):

        # Verifico modifiche alla connessione con il DB
        pglist = select([self._db_connection], [], [], timeout)

        if pglist != ([], [], []):
            self.poll_notification()
            return True

        return False

    # il polling sulle notifiche è bloccante su connessioni non asincrone
    def poll_notification(self):
        self._db_connection.poll()

    def get_notification(self):

        notify = None
        if self._db_connection.notifies:
            notify = self._db_connection.notifies.pop(0)

        # notify.pid, notify.channel, notify.payload
        return notify

    def begin_transaction(self):
        self._db_connection.autocommit = False

    def commit(self):
        self._db_connection.commit()

    def rollback(self):
        self._db_connection.rollback()

    def end_transaction(self):
        self._db_connection.autocommit = True

    def __del__(self):
        self._db_connection.close()

    def make_connection(self):

        dsn = 'dbname=%s user=%s host=%s password=%s' % (
            self.db, self.user, self.host, self.pwd)

        try:
            self._db_connection = psycopg2.connect(dsn)
            self._db_connection.autocommit = True
            self._db_cur = self._db_connection.cursor()

        except:
            self._db_cur = None
            print("Unable to connect to the database")
