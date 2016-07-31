#!/usr/bin/python
#-*- coding: utf8 -*-

import sys
import argparse
import Adafruit_DHT


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

# Try to grab a sensor reading.  Use the read_retry method which will retry up

c_retry = 0
humidity = None
temperature = None

while c_retry < args.retries: 
    humidity, temperature = Adafruit_DHT.read_retry(args.sensor, args.pin,
                                                    args.retries,
                                                    args.delay_seconds)
    c_retry += 1

    if humidity is None:
        break

    if humidity > 0 and humidity < 100:
        break

    humidity = None
    temperature = None

if humidity is not None and temperature is not None:
    print "{:f} {:f}".format(temperature, humidity)
else:
    raise SystemError("Impossibile leggere dati dal sensore")
