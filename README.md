# smac

Smac - Smart Raspberry/Arduino Clima System

Si osservi che il progetto è ancora via fase di sviluppo pertanto alcune caratteristiche potrebbero essere modificate nel tempo.

L'applicativo si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento con caldaia usando un dispositivo Rasperry.

A progetto terminato il repository conterrà tutto l'occorrente per poter installare l'applicativo su tale dispositivo:

- Codice PHP (versione supportata 5.5)
- Database con schema e dati minimali che consentano il funzionamento iniziale dell'applicativo. Verrà supportata la versione 9.x di Postgres che è quella che viene rilasciata con Raspian il sistema operativo dei Raspberry.
- Configurazione base del webserver Apache (httpd).
- Demoni, eseguibili e driver per l'interfacciamento e la gestione dell'hardware (sensori e relè)
- Schemi di collegamento sensori (per le misurazioni) e del Relè (per il controllo della caldaia)


Logicamente l'applicazione è suddivisa nei seguenti blocchi:

- Interfaccia Utente:

Un'interfaccia WEB, scritta in PHP. Lato client sono usate alcune librerie javascript (jquery, boostrap e plugin). Tutto l'occorrente è incluso nel repository.

Tramite interfaccia è possibile:

- controllare lo stato del sistema (accenzione, spegnimento, scelta programmi)
- definire un programma (temperature di riferimento, giorni e orari di applicazione)
- aggiungere un sensore (al momento sono supportati sensori DH11 e DH22 con misure di temperatura e umidità) e il parametro relativo al PIN GPIO dove il sensore è collegato.
- configurare parametri di base: temperatura anticongelamento, temperatura in caso di funzionamento manuale, pin GPIO dove è collegato il Relè che controlla la caldaia
- Visualizzare l'andamento dei dati atmosferici (al momento solo temperatura e umidità) rilevati dai sensori

- Il database.

È supportato esclusivamente il database Postgres versione 9.x. Viene fornito uno script di importazione che contiene i dati di base che consentono il funzionamento dell'applicazione. Il database è parte fondamentale di Smac; non ha solo il compito - ovvio - di conservare tutte le informazioni provenienti dai sensori e dall'interfaccia grafica, ma ha anche il compito di elaborazione dati e invio messaggi ai demoni che controllano l'hardware. Tali funizoni sono ottenute usando stored procedure e trigger.

- Interfacciamento con l'Hardware:

Si tratta di un insieme di script per lo più in python che si interfacciano con i sensori e relè. Usati sia per raccogliere i dati di teperatura/umidita dai sensori, sia per accedendere e spegnere la caldaia in base alla programmazione impostata.

I componenti software più importanti che si preoccupano di gestire l'hardware sono due, per ciascuno sono forniti gli script init.d per l'avvio automatico:

-- Collector: carica l'elenco dei sensori attivi e periodicamente legge i dati relativi a umidità e temperatura, memorizzandoli sul database. Al momento sono supportati i sensori DHT11 e DHT22 usando la libreria Adafruit_Python_DHT. Tale libreria va inizialmente compilata e installata tramite il programma di setup fornito. Il collector è in ascolto di eventi sulla tabella "sensori" in questo modo è in grado di modificare la configurazione nel caso in cui venga aggiunto rimosso o modificato un sensore.

-- Actuator: ha il compito di stabilire in base al programma selezionato dall'utente, e temperature di riferimento lo stato in cui deve trovarsi la caldaia: accesa o spenta. Non pilota direttamente la caldaia ma per farlo utilizza un altro demone Switcher. La comunicazione tra Actuator e Switcher avviene usando Pipe.

- Switcher: un demone python che controllando direttamente il PIN GPIO del relè accende o spegne la caldaia. Lo switcher reagisce ad alcuni segnali:
    - on : attiva il relè chiudendo il circuito e accendendo la caldaia
    - off: disattiva lo stato del relè aprendo il circuito e spegnendo la caldaia
    - status: riporta lo stato del relè (on oppure off)
    - load: carica la configurazione del relè
Lo switcher utilizza una named pipe (switcher_command) su cui rimane in ascolto dei comandi, provenienti generalmente dall'actuator. Eventuali risposte vengono inviate alla named pipe switcher_reponse.

-

L'applicativo in sè non prevede alcun meccanismo di autenticazione/autorizzazione - non ritengo che per applicativi di questo tipo siano necessari.

Vengono forniti comunque una serie di script e file di configurazione per configurare Apache in HTTPS con muutua autenticazione. Questo limita l'utilizzo dell'applicazione ai soli dispositivi che hanno certificati client validi.

Una particolarità dell'approccio allo sviluppo di questo applicativo è proprio il modo in cui viene usato il DB, che è considerato parte integrante dell'applicazione stessa e non solo come "mero" contenitore di dati. Il funzionamento stesso dell'applicazione è strettamente legato al DB, che tramite funzioni e trigger si occupa di elaborare i dati. Postgres è stato scelto proprio per la grande flessibilità di manipolazione dei dati in arrivo tramite regole, funzioni e trigger.

-

Installazione

apt-get install postgresql apache2 php5

mkdir /opt/smac
** copia intera cartella
ln -s /opt/smac/apache2/smac.conf /etc/apache2/conf.d/smac.conf
mkdir /opt/smac/log/
chown -R www-data /opt/smac/

a2enmod rewrite

/etc/init.d/

Creazione del Database

Modificare il file di configurazione di pg_hba.conf di Postgres in modo da consentire l'autenticazione MD5 per l'utente smac aggiungere la riga

    # TYPE  DATABASE        USER            METHOD
    local   smac            smac            password

che all'utente smac di autenticarsi con password esclusivamente su connessioni "Linux Socket" (generalmente tutte le connessioni effettuate su localhost o su ip 127.0.0.1), quando il database è smac.

Prima di procedere all'importazione del database stesso è necessario creare l'utente "smac" è l'omonimo database, con i grant necessari:
    su postgresq
    psql

    create user smac password smac
    create database smac
    grant all privileges on database smac to smac

Importare quindi uno dei due file del database:

psql -U smac smac < "nomefile.sql"

Installazione e configurazione dei demoni
    dalla directory /etc/init.d dell'applicativo copiare i tre script di init.d
        - collector
        - actuator
        - switcher
    procedere quindi all'installazione usando:
    sudo update-rc.d nome_demone defaults
