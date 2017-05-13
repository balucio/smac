#!/usr/bin/python
#-*- coding: utf8 -*-

'''
    Apertura gestione di una socket server usando thread.
    Gestisce l'acquisizione e l'invio di dati meteo ricevuti da sensori remoti
'''

import argparse
import Queue
import json
import socket
import sys
import threading

from daemon import Daemon
from datetime import datetime
from logging import INFO,DEBUG,CRITICAL

class SensorCollector(Daemon):

    SLEEP_TIME = 60
    DEF_LOG_LEVEL = CRITICAL #DEBUG

    def start(self, bind_address, bind_port ):
        """ Avvio il demone """

        self.sk = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sk.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.log.debug('Creata soket')

        #Bind socket to local host and port
        try:
            self.sk.bind((bind_address, bind_port))
        except socket.error as msg:
            print 'Impossibile associare l''interfaccia alla socket. Errore : ' + str(msg[0]) + ' Message ' + msg[1]
            sys.exit(1)

        self.log.debug('Socket associata all''indirizzo {}'.format(bind_address))
        # In ascolto sulla socket con una coda di 5 connessioni contemporanee
        self.sk.listen(5)
        self.log.info('In ascolto sulla porta {}'.format(bind_port))

        Daemon.start(self)

    def stop(self):
        try:
            s = self.sk.name
            s.close()
            s.shutdown()
        except AttributeError:
            pass

        Daemon.stop(self)

    def run(self):

        # locking
        self.lock = threading.Lock()
        # Creating shared structure
        sensors_data = {}

        # Gestisco le connessioni con i client
        while True:
            #wait to accept a connection - blocking call
            conn, addr = self.sk.accept()
            self.log.info('Connessio client {} : {}'.format(addr[0], addr[1]))
            # avvio il thread che servirà il client passando la connessione e le code
            c_handle = threading.Thread(self.serveClient, (conn, sensors_data, ))
            c_handle.start()
            self.sk.close()

    def datetime_handler(d):
        """ Gestisce la serializzazione json delle date """
        if isinstance(d, datetime):
            return d.isoformat()
        raise TypeError("Errore: data non corretta.")

    def serveClient(conn, sensors_data):
        """ Gestisce le connessioni in ingresso """

        # reading data from client
        raw_data = conn.recv(1024)
        if raw_data:
            self.lock.acquire()
            try:
                self.log.debug('Acquisisco il lock')
                data = json.loads(raw_data)
                sensor = data['sensore']
                oper = data['operazione']
                if sensor not in sensors_data:
                    sensors_data[sensor] = Queue.Queue()

                q = sensors_data[sensor]

                if oper == 'invio_dati':
                    q.put({
                        'sensor_name': sensor,
                        'valido' : data['valido'],
                        'date_time': datetime.today(),
                        'temperatura': data['temperatura'],
                        'umidita': data['umidita'],
                        'indice_calore' : data['indice_calore']
                    })
                    # invio ok al client
                    conn.send('OK')

                elif oper == 'acquisizione_dati' :
                    samples = [];
                    while not q.empty():
                        samples.append(q.get())

                    conn.send(json.dumps(samples, default=self.datetime_handler))

            except ValueError, e:
                self.log.error('Errore: impossibile decodificare i dati ricevuti ({})'.format(str(e)))
                conn.send('KO')
            except KeyError, e:
                self.log.error('Errore: parametro {} non presente'.format(str(e)))
                conn.send('KO')
            finally:
                lock.release()
                self.log.debug('Rilascio il lock')
                conn.send('KO')

        # chiudo la connessione con il client
        conn.close()

##############################
# Inizio programma principale

BIND_ADDRESS = '' # se vuoto tutti gli ip
BIND_PORT = 8080 # Porta non privilegiata sulla quale mettersi in ascolto

DAEMON_LOG = '/opt/smac/log/sensor_collector.log'
DAEMON_PID = '/var/run/sensor_collector/sensor_collector.pid'

if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "action", choices=['start', 'stop', 'reload'],
        help="Uso start|stop|restart")

    parser.add_argument(
        "--pid", required=False, nargs='?', default=DAEMON_PID,
        help="PID file del demone")

    parser.add_argument(
        "--log", required=False, nargs='?', default=DAEMON_LOG,
        help="LOG file")

    parser.add_argument(
        "--bind-port", required=False, nargs='?', default=BIND_PORT,
        help="Porta TCP sulla quale mettersi in ascolto [predefinito 8080]")

    parser.add_argument(
        "--bind-address", required=False, nargs='?', default=BIND_ADDRESS,
        help="Indirizzo IP dell'interfaccia sul quale creare la socket TCP [predefinito: tutti]")

    args = parser.parse_args()

    daemon = SensorCollector(args.pid, logfile=args.log)

    if 'start' == args.action:
        daemon.start(args.bind_address, args.bind_port)
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()
