#!/usr/bin/python
#-*- coding: utf8 -*-

import sys
import os
import time
import atexit

from signal import SIGTERM, SIGHUP
from smac_utils import setup_logger
from logging import getLogger


class Daemon(object):
    """
    A generic daemon class.

    Usage: subclass the Daemon class and override the run() method
    """
    def __init__(self, pidfile, stdin='/dev/null', stdout='/dev/null',
                 stderr='/dev/null', logfile='/dev/null'):

        self.stdin = stdin
        self.stdout = logfile
        self.stderr = logfile
        self.pidfile = pidfile

        # Creating pid dir if not exists
        pid_dir = os.path.dirname(self.pidfile)
        if not os.path.exists(pid_dir):
            os.makedirs(pid_dir)

        # Setup log file
        setup_logger(self.__class__.__name__, logfile, self.DEF_LOG_LEVEL)
        self.log = getLogger(self.__class__.__name__)

    def daemonize(self):
        """
        do the UNIX double-fork magic, see Stevens' "Advanced
        Programming in the UNIX Environment" for details (ISBN 0201563177)
        http://www.erlenstar.demon.co.uk/unix/faq_2.html#SEC16
        """
        try:
            pid = os.fork()
            if pid > 0:
                # exit first parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(
                "fork #1 failed: %d (%s)\n" % (e.errno, e.strerror)
            )
            sys.exit(1)

        # decouple from parent environment
        os.chdir("/")
        os.setsid()
        os.umask(0)

        # do second fork
        try:
            pid = os.fork()
            if pid > 0:
                # exit from second parent
                sys.exit(0)
        except OSError as e:
            sys.stderr.write(
                "fork #2 failed: %d (%s)\n" % (e.errno, e.strerror)
            )
            sys.exit(1)

        # redirect standard file descriptors
        sys.stdout.flush()
        sys.stderr.flush()
        si = file(self.stdin, 'r')
        so = file(self.stdout, 'a+')
        se = file(self.stderr, 'a+', 0)
        os.dup2(si.fileno(), sys.stdin.fileno())
        os.dup2(so.fileno(), sys.stdout.fileno())
        os.dup2(se.fileno(), sys.stderr.fileno())

        # write pidfile
        atexit.register(self.delpid)
        pid = str(os.getpid())
        file(self.pidfile, 'w+').write("%s\n" % pid)

    def check_pid(self, pid):
        """
        Check For the existence of a unix pid.
        """
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        else:
            return True

    def delpid(self):
        try:
            os.remove(self.pidfile)
        except OSError:
            return False
        else:
            return True

    def start(self):
        """
        Start the daemon
        """
        # Check for a pidfile to see if the daemon already runs
        try:
            pf = file(self.pidfile, 'r')
            pid = int(pf.read().strip())
            pf.close()
        except IOError:
            pid = None

        if pid:
            if not self.check_pid(pid):
                sys.stderr.write(
                    " pidfile %s exist, but process seems dead\n"
                    % self.pidfile)

                if self.delpid():
                    sys.stderr.write(" pidfile %s deleted\n" % self.pidfile)
                else:
                    sys.stderr.write(
                        " unable to delete pidfile %s\n" % self.pidfile)
                    sys.exit(1)
            else:
                sys.stderr.write(
                    " pidfile %s already exist. Daemon already running?\n"
                    % self.pidfile)
                sys.exit(1)

        # Start the daemon
        self.daemonize()
        self.run()

    def stop(self):
        """
        Stop the daemon
        """
        # Get the pid from the pidfile
        try:
            pf = file(self.pidfile, 'r')
            pid = int(pf.read().strip())
            pf.close()
        except IOError:
            pid = None

        if not pid:
            message = "pidfile %s does not exist. Daemon not running?\n"
            sys.stderr.write(message % self.pidfile)
            return  # not an error in a restart

        # Try killing the daemon process
        try:
            while 1:
                os.kill(pid, SIGTERM)
                time.sleep(0.1)
        except OSError as err:
            err = str(err)
            if err.find("No such process") > 0:
                if os.path.exists(self.pidfile):
                    self.delpid()
            else:
                print(str(err))
                sys.exit(1)

    def reload(self):
        """
        Invio segnale per ricaricare la configurazione
        """
        os.kill(os.getpid(), SIGHUP)

    def restart(self):
        """
        Restart the daemon
        """
        self.stop()
        self.start()

    def run(self):
        """
        You should override this method when you subclass Daemon.
        It will be called after the process has been
        daemonized by start() or restart().
        """
