#!/usr/bin/python
#-*- coding: utf8 -*-

from __future__ import print_function

import sys
import argparse
import socket
import json

BUFFER_SIZE = 4096

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

# Controllo argomenti:
# sensor-name, server-address, server-port
parser = argparse.ArgumentParser()

parser.add_argument(
    "--name", required=True,
    help="name: il nome del sensore da cui ricevere i dati")

parser.add_argument(
    "--server", required=False, default="127.0.0.1",
    help="server: l'indirizzo o il nome del server da cui ricevere i dati")

parser.add_argument(
    "--port", required=False, type=int, nargs='?', default=8080,
    help="port: il numero di porta TCP in cui il server è in ascolto")

args = parser.parse_args()

msg = {
    "sensore" : args.name,
    "operazione":  "acquisizione_dati"
}

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((args.server, args.port))
    s.send(json.dumps(msg))
    data = s.recv(BUFFER_SIZE)
except:
    eprint("Errore: Impossibile comunicare con il Remote Collector {}:{}".format(args.server, args.port))
    sys.exit(1)

if data == 'KO':
    eprint("Errore: RemoteCollector non è stato in grado di elaborare la richiesta")
    sys.exit(1)
elif data == "[]":
    eprint("Attenzione: Nessuna misurazione in coda per il sensore {}".format(args.name))
    sys.exit(2)
print(data)
