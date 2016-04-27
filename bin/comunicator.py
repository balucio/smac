#!/usr/bin/python
#-*- coding: utf8 -*-

import os
import stat
import select
import re

from locale import getpreferredencoding


class Comunicator(object):

    MODE_SERVER = 'SERVER'
    MODE_CLIENT = 'CLIENT'

    hpipein = None

    def __init__(self, mode, pipe_name_in, pipe_name_out):

        self.pipe_name_in = pipe_name_in
        self.pipe_name_out = pipe_name_out

        self.mode = mode

        # In modalità client devo scambiare le due pipe
        if mode == self.MODE_SERVER:
            self._create_pipe(self.pipe_name_in)
            self._create_pipe(self.pipe_name_out)
        elif mode == self.MODE_CLIENT:
            self.pipe_name_in = pipe_name_out
            self.pipe_name_out = pipe_name_in
        else:
            raise ValueError('Modalità %s sconosciuta' % mode)

    def send_message(self, pid, message, timeout=15.0):

        pipeout = self._open_pipe(
            self.pipe_name_out, os.O_WRONLY)

        if pipeout is None:
            return False

        try:
            poll = select.poll()
            poll.register(pipeout, select.POLLOUT)

            if len(poll.poll(timeout)):
                os.write(pipeout, "[%s]: %s\n" % (pid, message))
                ret = True
            else:
                print("Timeout in scrittura messaggio: %s" % (message))
                ret = False
        except (OSError, IOError) as e:
            print("Errore scrittura messaggio: %s" % (repr(e)))
            ret = False
        else:
            os.close(pipeout)

        return ret

    def read_message(self, timeout=15.0):

        pipein = self._open_pipe(
            self.pipe_name_in, os.O_RDONLY | os.O_NONBLOCK)

        if not pipein:
            return (os.getpid(), 'ERROR')

        try:
            msg = None
            poll = select.poll()
            poll.register(pipein, select.POLLIN | select.POLLPRI)

            if len(poll.poll(timeout)):

                rawmsg = self._read_line(pipein)
                #print("Messaggio raw: %s" % (rawmsg))

                match = re.match(r'^\[([^]]+)\]\s?:\s?([\w\s:]+)', rawmsg)

                if match:
                    msg = (match.group(1), match.group(2))
                else:
                    print("Formato messaggio errato: %s" % (rawmsg))
                    msg = (os.getpid(), 'ERROR')
            else:
                msg = (os.getpid(), 'TIMEOUT')

        except (OSError, IOError) as e:
            print("Errore lettura messaggio: %s" % (repr(e)))
            msg = (os.getpid(), 'ERROR')

        finally:
            os.close(pipein)

        return msg

    def _create_pipe(self, pipe_name):

        if not os.path.exists(pipe_name):
            os.mkfifo(pipe_name)

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
            if stat.S_ISFIFO(os.stat(name).st_mode):
                ph = os.open(name, mode)
        except (OSError, IOError) as e:
            print("Errore apertura %s: %s" % (name, repr(e)))

        return ph

    def __del__(self):
        os.remove(self.pipe_name_in)
        os.remove(self.pipe_name_out)
