# Smac Utils
#

import re
import logging

from datetime import datetime
from logging.handlers import TimedRotatingFileHandler

DBCONFIG = '/opt/smac/www/html/configs/DbConfig.php'
BASE_LOG = '/opt/smac/log/'
SWITCHER_PIPE_IN = '/tmp/switcher_in'
SWITCHER_PIPE_OUT = '/tmp/switcher_out'


def second_to_time(seconds):
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    d, h = divmod(h, 24)
    return "%dg %d:%02d:%02d" % (d, h, m, s)


def epoch_timestamp():
    return float(datetime.now().strftime('%s'))


def second_since_midnight():
    now = datetime.now()
    return (now - now.replace(
            hour=0, minute=0, second=0, microsecond=0)
            ).total_seconds()


def read_db_config():

        fd = open(DBCONFIG, "r")
        data = fd.read()
        rx = re.compile(r'const[^\w]+(\w+)[^=]+[^\w]+(\w+)', re.MULTILINE)
        raw_set = [m.groups() for m in rx.finditer(data)]
        db_set = {}
        for s in raw_set:
            db_set[s[0]] = s[1]

        return db_set


def setup_logger(logger_name, log_file, level=logging.INFO):
    l = logging.getLogger(logger_name)
    formatter = logging.Formatter('%(asctime)s : %(message)s')
    # max 5 giorni di log poi ruota
    fileHandler = TimedRotatingFileHandler(log_file, when='D', interval=5)
    fileHandler.setFormatter(formatter)
    streamHandler = logging.StreamHandler()
    streamHandler.setFormatter(formatter)

    l.setLevel(level)
    l.addHandler(fileHandler)
    l.addHandler(streamHandler)
