#!/usr/bin/python
#-*- coding: utf8 -*-

import os
import select
import re

from locale import getpreferredencoding
from time import sleep


class Comunicator(object):

    MODE_SERVER = 'SERVER'
    MODE_CLIENT = 'CLIENT'

    WRITE_ATTEMPTS = 3.0

    def __init__(self, mode, pipe_name_in, pipe_name_out, log):

        self.pipe_name_in = pipe_name_in
        self.pipe_name_out = pipe_name_out

        self.mode = mode
        self._log = log

        # In modalità client devo scambiare le due pipe
        if mode == self.MODE_SERVER:
            self._create_pipe(self.pipe_name_in)
            self._create_pipe(self.pipe_name_out)
        elif mode == self.MODE_CLIENT:
            self.pipe_name_in = pipe_name_out
            self.pipe_name_out = pipe_name_in
        else:
            err_msg = 'Modalità %s sconosciuta' % (mode)
            self._log.error(err_msg)
            raise ValueError(err_msg)

    def send_message(self, pid, message, timeout=None):

        open_sleep = timeout / self.WRITE_ATTEMPTS
        curr_attempt = 0
        open_attempts = self.WRITE_ATTEMPTS
        mode = os.O_WRONLY

        if timeout is not None:
            mode |= os.O_NONBLOCK

        # Write non bloccante se c'è un timeout ma devo rispettarlo
        while curr_attempt <= open_attempts:
            pipeout = self._open_pipe(self.pipe_name_out, mode)

            if (
                pipeout is not None or timeout is None
                or curr_attempt == open_attempts
            ):
                break

            curr_attempt += 1
            sleep(open_sleep)

        if pipeout is None:
            self._log.error("Timeout apertura pipe in scrittura")
            return False

        try:
            poll = select.poll()
            poll.register(pipeout, select.POLLOUT)
            if len(poll.poll(timeout)):
                os.write(pipeout, "[%s]: %s\n" % (pid, message))
                ret = True
            else:
                self._log.error("Timeout apertura pipe in scrittura")
                ret = False
        except (OSError, IOError) as e:
            self._log.error("Errore scrittura messaggio: %s", repr(e))
            ret = False
        else:
            os.close(pipeout)

        return ret

    def read_message(self, timeout=None):

        mode = os.O_RDONLY

        # Read non bloccante se è impostato un timeout
        # Rispetterò il timeout nella poll
        if timeout is not None:
            mode |= os.O_NONBLOCK

        pipein = self._open_pipe(self.pipe_name_in, mode)

        if not pipein:
            return (os.getpid(), 'ERROR')

        try:
            msg = None
            poll = select.poll()
            poll.register(pipein, select.POLLIN)

            if len(poll.poll(timeout)):

                rawmsg = self._read_line(pipein)
                self._log.debug("Messaggio raw: %s", rawmsg)

                match = re.match(r'^\[([^]]+)\]\s?:\s?([\w\s:]+)', rawmsg)

                if match:
                    msg = (match.group(1), match.group(2))
                else:
                    self._log.warning("Formato messaggio errato: %s", rawmsg)
                    msg = (os.getpid(), 'ERROR')
            else:
                msg = (os.getpid(), 'TIMEOUT')

        except (OSError, IOError) as e:
            self._log.warning("Errore lettura messaggio: %s", repr(e))
            msg = (os.getpid(), 'ERROR')

        finally:
            os.close(pipein)

        return msg

    def _create_pipe(self, pipe_name):

        try:
            if not os.path.exists(pipe_name):
                os.mkfifo(pipe_name)
        except Exception as e:
            self._log.error("Errore creazione pipe %s: %s", pipe_name, repr(e))

    def _read_line(self, pipe):

        buf = bytearray()
        enc = getpreferredencoding(False)

        while True:
            ch = None
            try:
                ch = os.read(pipe, 1)
            except:
                pass

            if not ch:
                break
            elif ch != "\n":
                buf.extend(ch)

        return buf.decode(enc)

    def _open_pipe(self, name, mode):

        ph = None

        try:
            self._create_pipe(name)
            ph = os.open(name, mode)
        except (OSError, IOError) as e:
            self._log.debug(
                "Errore apertura PIPE %s in %s: %s", name, mode, repr(e))

        return ph

    def __del__(self):
        os.remove(self.pipe_name_in)
        os.remove(self.pipe_name_out)
