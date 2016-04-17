#!/usr/bin/python
#-*- coding: utf8 -*-

import os
import stat
import select
import re


class Comunicator(object):

    MODE_SERVER = 'SERVER'
    MODE_CLIENT = 'CLIENT'

    pipe_name_in = None
    pipe_name_out = None

    pipein = None
    pipeout = None

    def __init__(self, mode, pipe_name_in, pipe_name_out):

        self.pipe_name_in = pipe_name_in
        self.pipe_name_out = pipe_name_out

        # In modalità client devo scambiare le due pipe
        if mode == self.MODE_SERVE:
            self._cretate_pipe(self.pipe_name_in)
            self._cretate_pipe(self.pipe_name_out)
        elif mode == self.MODE_CLIENT:
            self.pipe_name_in = pipe_name_out
            self.pipe_name_out = pipe_name_in
        else:
            raise ValueError('Modalità %s sconosciuta' % mode)

        self.pipein = self._open_pipe(self.pipe_name_in, os.O_RDONLY)
        self.pipeout = self._open_pipe(self.pipe_name_out, os.O_WRONLY)

    def send_message(self, pid, message):

        if self.pipeout:
            os.write(self.pipeout, "[%s]: %s\n" % (pid, message))
            return True
        else:
            return False

    def read_message(self, timeout=5.0):

        if self.pipein is None:
            return None

        msg = (os.getpid(), 'ERROR')

        try:
            rlist, wlist, xlist = select.select([self.pipein], [], [], timeout)

            if self.pipein in rlist:
                rawmsg = os.readline()[:-1]
                match = re.match(r'^\[([^]]+)\] : ([\w ]+)', rawmsg)
                if match is not None:
                    msg = (match.group(1), match.group(2))
            else:
                msg = (os.getpid(), 'TIMEOUT')

        except (OSError, IOError) as e:
            print("Errore lettura messaggio: %s" % (repr(e)))

        return msg

    def _cretate_pipe(pipe_name):

        if not os.path.exists(pipe_name):
            os.mkfifo(pipe_name)

    def _open_pipe(self, name, mode):

        ph = None

        try:
            if stat.S_ISFIFO(os.stat(name).st_mode):
                ph = os.open(name, mode)
        except (OSError, IOError) as e:
            print("Errore apertura %s: %s" % (name, repr(e)))

        return ph

    def __del__(self):

        if self.pipein:
            self.pipein.close()

        if self.pipeout:
            self.pipeout.close()
