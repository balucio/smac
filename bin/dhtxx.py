#!/usr/bin/python
#-*- coding: utf8 -*-

import sys
import time
import argparse
import Adafruit_DHT

def dixon_value(data):
 
    data.sort()
    denom = data[2] - data[0]
    
    dixon1 = (data[1] - data[0]) / denom
    dixon2 = (data[2] - data[1]) / denom

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

THR_H = 5 # soglia errore umidità
THR_T = 2 # soglia errore temperatura
THR_DIXON = 0.

# Numero massimo di letture 
READINGS=3

# prima lettura dati
h, t = Adafruit_DHT.read_retry(args.sensor, args.pin,
                               args.retries,
                               args.delay_seconds)

if h is None or t is None:
    raise SystemError("Impossibile leggere dati dal sensore")

temperature = t
humidity = h
i = 1

reads_h = []
reads_t = []

while i < READINGS:

    # pausa prima di rileggere il sensore
    time.sleep(1)

    h, t = Adafruit_DHT.read_retry(args.sensor, args.pin,
                                   args.retries,
                                   args.delay_seconds)
    if h is None or t is None:
        break
   
    # salvo le letture
    reads_h += [h]
    reads_t += [t]

    # sommo per la media
    temperature += t     
    humidity += h       
    i+=1
  
    # Esco se l'errore assoluto rispetto alla media è minore delle tolleranze
    if abs( h - ( humidity / i ) ) <= THR_H and abs( ( t - temperature / i ) ) <= THR_T:
       break

# Usando il test di Dixon elimino il valore che probabilmente è meno corretto
# calcolandone la media
if i > 2:
    humdity = dixon_value(reads_h)
    temperature = dixon_value(reads_t)
else:
    humidity /= i
    temperature /= i

print "{:f} {:f}".format(temperature, humidity)
