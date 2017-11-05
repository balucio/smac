#!/usr/bin/python
#-*- coding: utf8 -*-

import sys
import time
import argparse
import Adafruit_DHT

def dixon_reduce(data):
 
    data.sort()
    denom = data[2] - data[0]
    
    dixon1 = (data[1] - data[0]) / denom if denom > 0 else 0
    dixon2 = (data[2] - data[1]) / denom if denom > 0 else 0

    if dixon1 < dixon2:
        del data[0]
    elif dixon1 > dixon2:
        del data[2]

    return sum(data) / float(len(data))


def check_interval(value, vmin, vmax):

    ivalue = int(value)

    if ivalue < vmin or ivalue > vmax:
        raise argparse.ArgumentTypeError(
            "Il valore deve essere compreso nell'intervallo tra %s e %s "
            % (vmin, vmax))

    return ivalue


def check_retries(value):
    return check_interval(value, 1, 7)


def check_delay(value):
    return check_interval(value, 2, 10)

# Controllo argomenti:
# sensor=11, retries=7, delay_seconds=3
parser = argparse.ArgumentParser()

parser.add_argument(
    "--sensor", required=True, type=int, choices=[11, 22, 2302],
    help="sensor: il tipo di sensore da interrogare, può essere uno tra 11, 22 o 2302")

parser.add_argument(
    "--pin", required=True, type=int, choices=[4, 17, 18, 22, 23, 24, 25, 27],
    help="pin: il numero di pin GPIO del raspberry dove il sensore è connesso")

parser.add_argument(
    "--retries", required=False, type=check_retries, nargs='?', default=7,
    help="retries: il numero di tentativi di interrogazione del sensore")

parser.add_argument(
    "--delay_seconds", required=False, type=check_delay, nargs='?', default=3,
    help="delay_seconds: l'intervallo tra ciascun tentativo")

args = parser.parse_args()

# h = umidità, t = temperatura

MIN_H = 0
MAX_H = 100

MIN_T = -20
MAX_T = 60

READ_ERR_MAX = 2

THR_DIXON = 0.

# Numero di letture
READINGS=1

i = 0
read_errors = 0

reads_h = []
reads_t = []

# Si dovrebbero ottenere risultati migliori facendo eseguire al sensore
# almeno tre misurasioni e applicando la riduzione Dixon ai risultati
while i < READINGS:

    h, t = Adafruit_DHT.read_retry(args.sensor, args.pin,
                                   args.retries,
                                   args.delay_seconds)

    # in caso di letture errate aumento la pausa tra le letture
    if h is None or t is None or h < MIN_T or h > MAX_H or t < MIN_T or t > MAX_T:
	read_errors += 1
	if read_errors > READ_ERR_MAX:
	    raise SystemError("Superato il limite massimo di letture errate")
        time.sleep(read_errors)
        continue

    # salvo le letture
    reads_h += [h]
    reads_t += [t]

    i+=1

    # pausa per la prossima lettura
    time.sleep(3)

# In caso di tre misurazioni viene applicato il test di dixon per
# eliminare il valore probabilmente meno corretto
if READINGS == 3:
    humidity = dixon_reduce(reads_h)
    temperature = dixon_reduce(reads_t)
else:
    humidity = reads_h[0]
    temperature = reads_t[0]

print "{:f} {:f}".format(temperature, humidity)
