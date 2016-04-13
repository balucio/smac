#!/usr/bin/python
#-*- coding: utf8 -*-

import psycopg2

class Database(object):

    _db_connection = None
    _db_cur = None

    def __init__(self, host, user, pwd, db):

        self.host = host
        self.user = user
        self.pwd = pwd
        self.db = db

        self.make_connection()
        self._db_cur = self._db_connection.cursor()

    def query(self, query, params=None):
        self._db_cur.execute(query, params)
        return self._db_cur.fetchall()

    def lock_table(self, table, lock_mode = 'ROW EXCLUSIVE'):
        self._db_cur.execute('LOCK %s IN %s MODE' % (table, lock_mode))


    def insert_many(self, query, values):
        self._db_cur.executemany(query, values)

    def set_notification(self, notification):
        self._db_cur.execute('LISTEN ' + notification)

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

        dsn = 'dbname=' + self.db + ' user=' + self.user + ' host=' + self.host + ' password=' + self.pwd

        try:
            _db_cur = None
            self._db_connection = psycopg2.connect(dsn)
            self._db_connection.autocommit = True
            self._db_cur = self._db_connection.cursor()
        except:
                print "Unable to connect to the database"