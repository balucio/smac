#!/usr/bin/python
#-*- coding: utf8 -*-

'''
    Apertura gestione di una socket server usando thread.
    Gestisce l'acquisizione e l'invio di dati meteo ricevuti da sensori remoti
'''

import argparse
import json
import socket
import sys
import threading

from daemon import Daemon
from datetime import datetime
from collections import deque
from logging import INFO,DEBUG,CRITICAL,WARNING

class RemoteCollector(Daemon):

    SLEEP_TIME = 60
    DEF_LOG_LEVEL = WARNING #CRITICAL WARNING INFO
    BUFFER_SIZE = 1024
    MAX_SEND_SAMPLE = 30

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
            self.log.info('Connessione con client {} : {}'.format(addr[0], addr[1]))
            # avvio il thread che servirà il client passando la connessione e le code
            c_handle = threading.Thread(target=self.serveClient, args=(conn, sensors_data, ))
            c_handle.start()

    def datetime_handler(self, d):
        """ Gestisce la serializzazione json delle date """
        if isinstance(d, datetime):
            return d.isoformat()
        raise TypeError("Errore: data non corretta.")

    def serveClient(self, conn, sensors_data):
        """ Gestisce le connessioni in ingresso """

        # reading data from client
        raw_data = conn.recv(RemoteCollector.BUFFER_SIZE)
        if raw_data:
            self.log.debug('Acquisisco il lock')
            self.lock.acquire()
            try:
                self.log.debug('Dati ricevuti: {}'.format(raw_data))
                data = json.loads(raw_data)
                sensor = data['sensore']
                oper = data['operazione']
                # se non esiste ancora creo un coda
                if sensor not in sensors_data:
                    sensors_data[sensor] = deque(maxlen=500)
                    self.log.debug('Creo nuova coda per il sensore {}'.format(sensor))

                q = sensors_data[sensor]

                if oper == 'invio_dati':
                    self.log.debug('Ricevo e accodo i dati del sensore {}'.format(sensor))
                    if len(q) >= q.maxlen:
                        self.log.error('Coda sensori piena, il vecchi valori verranno sovrascritti.')
                    q.append({
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
                    self.log.debug('Restituisco i dati del sensore {}'.format(sensor))
                    samples = [];
                    sent = 0
                    while sent <= RemoteCollector.MAX_SEND_SAMPLE and q:
                        samples.append(q.pop())
                        sent+=1
                        self.log.debug('Rimuovo dalla coda i dati {}'.format(samples[-1]))

                    conn.send(json.dumps(samples, default=self.datetime_handler))

            except ValueError, e:
                self.log.error('Errore: impossibile decodificare i dati ricevuti ({})'.format(str(e)))
                conn.send('KO')
            except KeyError, e:
                self.log.error('Errore: parametro {} non presente'.format(str(e)))
                conn.send('KO')
            finally:
                self.lock.release()
                self.log.debug('Rilascio il lock')
                # chiudo la connessione con il client
                conn.close()

##############################
# Inizio programma principale

BIND_ADDRESS = '' # se vuoto tutti gli ip
BIND_PORT = 8080 # Porta non privilegiata sulla quale mettersi in ascolto

DAEMON_LOG = '/opt/smac/log/remote_collector.log'
DAEMON_PID = '/var/run/remote_collector/remote_collector.pid'

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

    daemon = RemoteCollector(args.pid, logfile=args.log)

    if 'start' == args.action:
        daemon.start(args.bind_address, args.bind_port)
    elif 'stop' == args.action:
        daemon.stop()
    elif 'restart' == args.action:
        daemon.restart()
