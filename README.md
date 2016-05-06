# smac

Smac - Smart Raspberry Clima System

Il progetto è ancora via fase di sviluppo pertanto alcune caratteristiche potrebbero essere modificate nel tempo.

Questo progetto si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento con caldaia usando un dispositivo Rasperry. Sono forniti gli schemi per Raspberry, dai quali possono essere facilmente ricavati quelli per Arduino.

A progetto terminato il repository conterrà tutto l'occorrente per poter installare l'applicativo direttamente sul dispositivo Rasperry.

- Codice PHP (versione supportata >= 5.4)
- Database con schema e dati minimali che consentano il funzionamento iniziale dell'applicativo.
  Al momento sono supportate esclusivamente le versioni 9.x di Postgresql. La versione 7 di Raspian utilizza Postgresl
  versione 9.1.20.
- Configurazione base del webserver Apache (httpd).
- Demoni, eseguibili e driver per l'interfacciamento e la gestione dell'hardware (sensori e relè)
- Schemi di collegamento sensori (per le misurazioni) e del Relè (per il controllo della caldaia)

### Struttura della directory del progetto

Il programma è progettato per essere installato il `/opt/smac`. È possibile variare questo percorso modificando alcune definizioni usate nel codice PHP e nei vari demoni. Alcuni script e file di configurazioni non potendo usare definizioni comuni potrebbero avere questo percorso codificato, pertanto è necessario assicurarsi di modificare tutti i puntamenti cercandoli usando `grep` nella directory del progetto.

La directory principale del progetto contiene:

- smac          -> directory principale
  - apache2     -> directory contentente i file di configurazione del webserver apache2
    - smac.conf -> contiene la definizione del virtual host per il funzionamento dell'interfaccia
                   web di Smac. Va copiata o meglio ancora "linkata" in /etc/apache2/conf.d/
  - bin         -> contiene gli script e librerie (per lo più in python) che consentono di gestire
                   sensori e la comunicazione tra i processi. Alcuni di questi script verranno
                   eseguiti come demoni di sistema e si occuperanno della lettura dei dati dei
                   sensori e della comunicazione con la caldaia pilotando il Relè.
                   Si consiglia di effettuare l'avvio dei demoni solo dopo aver configurato
                   correttamente dall'interfaccia Web dell'applicativo i parametri relativi ai numeri
                   di Pin della GPIO del Rasperry. Infatti sia i sensori di temperatura che il
                   Relè che pilota la caldaia sono pilotati da uno specifico Pin della GPIO.
                   Si tenga presente che l'applicazione esegue controlli minimali sulla correttezza
                   dei numeri di Pin inseriti, pertanto è necessario prestare molta attenzione alla
                   corretta configurazione di tali valori. L'applicazione usa la numerazione BCM
                   dell'interfaccia GPIO.
  - driver      -> contiene i sorgenti per compilare i driver di interfacciamento con i Sensori di
                   temperatura. Al momento sono supportati i sensori DHT11 e DHT22 di Adafruit.
                   I driver Adafruit contengono una libreria Python da compilare e installare.
                   Eseguita l'installazione la directory driver non è più necessaria.
  - database    -> contiene uno schema base per consentire l'avvio dell'applicativo Web
  - etc
    - cron.daily -> contiene un job cron per l'aggiornamento quotidiano delle statistiche
    - init.d    -> contiene gli script di avvio dei demoni python
  - log         -> contiene i log generato dall'applicativo web e dai demoni
  - www         -> contiene la parte applicativa web
    - tpl       -> contiene i modelli (template) delle pagine web generate dall'applicazione
    - html      -> l'applicativo web completo inclusi css e librerie javascript.

### Struttura logica dell'applicazione

Logicamente l'applicazione è suddivisa nei seguenti blocchi:

- Interfaccia Web
- Demoni e script di controllo
- Database

#### Interfaccia Web
Un'interfaccia WEB, scritta in PHP. Lato client sono usate alcune librerie javascript (jquery, boostrap e alcuni plugin). Tutto l'occorrente è incluso nel repository.

L'interfaccia web consente di:

- controllare lo stato del sistema (accenzione, spegnimento, scelta programmi)
- definire un programmi (temperature di riferimento, giorni e orari di applicazione)
- aggiungere un sensori (al momento sono supportati sensori DH11 e DH22 con misure di temperatura e umidità) e il parametro relativo al PIN GPIO dove il sensore è collegato.
- configurare parametri di base: temperatura anticongelamento, temperatura in caso di funzionamento manuale, pin GPIO dove è collegato il Relè che controlla la caldaia
- Visualizzare l'andamento dei dati atmosferici (al momento solo temperatura e umidità) rilevati dai sensori

L'utilizzo di bootstrap dovrebbe garantire a progetto terminato di poter visualizzare correttamente l'interfaccia Web su qualsiasi dispositivo mobile.

#### Il database.

È supportato esclusivamente il database **Postgres versione 9.x.**. Viene fornito uno script di importazione che contiene i dati di base che consentono il funzionamento dell'applicazione. Il database è parte fondamentale di **Smac**, non ha solo il compito - ovvio - di conservare tutte le informazioni provenienti dai sensori e dall'interfaccia grafica, ma ha anche quello di elaborazione dati e invio messaggi ai demoni che controllano l'hardware. Tali funizoni sono ottenute usando stored procedure e trigger.

Nello specifico grazie al supporto degli _eventi_ di Posgresql, il Database viene usato come una sorta di IPC (Inter Process Communication), ciò permette di lasciare sul Raspberry solo i **Demoni e gli script di Controllo** e installare su sistemi diversi l'applicazione Web e il Database stesso.

#### Demoni e script di controllo

Si tratta di un insieme di script per lo più in _Python_ che si interfacciano con i sensori e relè. Sono usati sia per raccogliere i dati di _temperatura_ e _umidita_ dai sensori, sia per accedendere e spegnere la caldaia (Tramite il controllo di un Relè) in base alla programmazione impostata.

I componenti software più importanti che si preoccupano di gestire l'hardware sono i seguenti, per ciascuno sono forniti gli script init.d per l'avvio automatico:

- **Collector**: carica l'elenco dei sensori attivi e periodicamente legge i dati relativi a umidità e temperatura, memorizzandoli sul database. Al momento sono supportati i sensori DHT11 e DHT22 usando la libreria Adafruit_Python_DHT. Tale libreria va inizialmente compilata e installata tramite il programma di setup fornito. Il collector è in ascolto di eventi sulla tabella "sensori" in questo modo è in grado di modificare la configurazione nel caso in cui venga aggiunto rimosso o modificato un sensore.
- **Actuator**: ha il compito di stabilire in base al programma selezionato dall'utente, e la temperatura di riferimento lo stato in cui deve trovarsi la caldaia: _accesa_ o _spenta_. Non pilota direttamente la caldaia ma per farlo utilizza il demone _Switcher_. La comunicazione tra Actuator e Switcher avviene usando Pipe.
- **Switcher**: questo demono ha il compito di controllare il PIN GPIO sul quale è collegato il Relé accendendo o spegnendo la caldaia. Lo switcher reagisce ad alcuni segnali che vengono inviati su named pipe:
    - on : attiva il relè chiudendo il circuito e accendendo la caldaia
    - off: disattiva lo stato del relè aprendo il circuito e spegnendo la caldaia
    - status: riporta lo stato del relè (on oppure off)
    - load: carica la configurazione del relè

   La gestione della named pipe è delegata all'oggetto (switcher_command). Questo in effetti crea due named pipe, una è usata per inviare comandi allo **switcher** l'atra per riceverne messaggi.-

#### Sicurezza
L'applicativo in sè non prevede alcun meccanismo di autenticazione/autorizzazione - non ritengo che per applicativi di questo tipo siano necessari.
Per l'accesso dall'esterno, può essere utile usare HTTPS con muutua autenticazione. Questo limita l'utilizzo dell'applicazione ai soli dispositivi che hanno certificati client validi.

#### Note Tecniche
Una particolarità dell'approccio allo sviluppo di questo applicativo è proprio il modo in cui viene usato il DB, che è considerato parte integrante dell'applicazione stessa e non solo come "mero" contenitore di dati. Il funzionamento stesso dell'applicazione è strettamente legato al DB, che tramite funzioni e trigger si occupa di elaborare i dati. Postgres è stato scelto proprio per la grande flessibilità di manipolazione dei dati in arrivo tramite regole, funzioni e trigger.


## Installazione

La procedura prevede l'installazione di Apache come WebServer, nel caso in cui tutto fosse installato sul Raspberry, si consiglia di usare un altro WebServer più leggero come **Ngnix**

- Installazione dipendenze

        sudo apt-get install postgresql apache2 php5

- Installazione librerie python per il controllo GPIO

        sudo apt-get install python-rpi.gpio

- Compilazione dei driver Adafruit Python

        cd <smac>/drivers/Adafruit_Python_DHT/
        python setup.py build
        python setup.py install
   la directory _Adafruit_Python_DHT_ può essere eliminata dopo l'installazione e la compilazione e l'installazione dei driver.

- Installazione dei binari e configurazione di Apache:

    - creazione directory base
    
            mkdir /opt/smac
    - copia dei file necessari:
    
       copiare in `/opt/smac` le seguenti directory da quella del progetto
       
            apache2
            bin
            ect
            www

- Installazione configurazione apache (accertarsi che il mod_rewrite sia installato)

        ln -s /opt/smac/apache2/smac.conf /etc/apache2/conf.d/smac.conf
        mkdir /opt/smac/log/
        chown -R www-data /opt/smac/www
        chmod +x /opt/smac/bin/*

   Abilitazione del modrewrite
   
        a2enmod rewrite

- Configurazione e importazione del Database

   Abilitare l'utente smac per la connessione locale con password su "Linux Socket" (localhost) modificando il file pg_hba.conf. Nell'installazione standard tale file dovrebbe trovarsi in /etc/postgresql/9.1/main

    Usare l'editor `vi`:
    
        vi /etc/postgresql/9.1/main/pg_hba.conf

    Aggiungere la seguente riga

        # TYPE  DATABASE        USER            METHOD
        local   smac            smac            password

   Usare l'utente postgres per importare il database, che contiene la struttura e i dati minimali per consentire il funzionamento dell'applicativo.

        su postgresq
        psql < "/opt/smac/database/postgres_database_schema.sql"

- Installazione e configurazione dei demoni
    usando il comando `ln` collegare i demoni **collector**, **actuator**, **switcher** da /opt/smac/etc/init.d/ in /etc/init.d

        ln -s /opt/smac/etc/init.d/<nome_demone> /etc/init.d/<nome_demone>

    procedere quindi all'installazione usando:
    
        for daemon in collector, actuator, switcher; do sudo update-rc.d -f $daemon remove; done
        for daemon in collector, actuator, switcher; do sudo update-rc.d -f $daemon defaults; done

- Configurazione dei cron job
    Installare un cronjob che ha il compito di aggiornare la situazione giornaliera sul database:

        chmod +x /opt/smac/etc/cron.daily/update_stats
        ln -s /opt/smac/etc/cron.daily/update_stats /etc/cron.daily/update_stats

