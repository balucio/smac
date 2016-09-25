# smac

Smac - Smart Raspberry Clima System

Il progetto è ancora via fase di sviluppo pertanto alcune caratteristiche potrebbero essere modificate nel tempo.

Questo progetto si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento con caldaia usando un dispositivo Rasperry. Sono forniti gli schemi per Raspberry, dai quali possono essere facilmente ricavati quelli per Arduino.

A progetto terminato il repository conterrà tutto l'occorrente per poter installare l'applicativo direttamente sul dispositivo Rasperry.

- Codice PHP (versione supportata >= 5.4)
- Database con schema e dati minimali che consentano il funzionamento iniziale dell'applicativo.
  Al momento sono supportate esclusivamente le versioni 9.x di Postgresql. La versione 7 di Raspian utilizza Postgresl versione 9.1.20.
- Configurazione base del webserver Apache (httpd).
- Demoni, eseguibili e driver per l'interfacciamento e la gestione dell'hardware (sensori e relè)
- Schemi di collegamento sensori (per le misurazioni) e del Relè (per il controllo della caldaia)

Da alcuni test eseguiti il Raspberry 2 è in grado di gestire tranquillamente il webserver (quindi l'applicativo web), i demoni di controllo e il database (Postgres). Con modifiche minime sono tuttavia possibili configurazioni miste, per esempio: un server esterno per servire le pagine PHP e il database, e utilizzare il raspberry solo per i demoni di controllo sensori. L'unico requisito è che sia il rasbperry che il server che ospita l'applicativo web riescano a raggiungere il Database.
Queste possiblità rendono più semplice un eventuale porting su Arduino.

### Struttura della directory del progetto

Il programma è progettato per essere installato il `/opt/smac`. È possibile variare questo percorso modificando alcune definizioni usate nel codice PHP e nei vari demoni. Alcuni script e file di configurazioni non potendo usare definizioni comuni potrebbero avere questo percorso codificato, pertanto è necessario assicurarsi di modificare tutti i puntamenti cercandoli usando `grep` nella directory del progetto.

La directory principale del progetto contiene:

- smac: directory principale
  - apache2: contiene i file di configurazione del webserver apache2
    - smac.conf: contiene la definizione del virtual host per il funzionamento dell'interfaccia
                   web di Smac. Va copiata o meglio ancora "linkata" in /etc/apache2/conf.d/
  - bin:         contiene gli script e librerie (per lo più in python) che consentono di gestire
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
  - driver:     contiene i sorgenti per compilare i driver di interfacciamento con i Sensori di
                   temperatura. Al momento sono supportati i sensori DHT11 e DHT22 di Adafruit.
                   I driver Adafruit contengono una libreria Python da compilare e installare.
                   Eseguita l'installazione la directory driver non è più necessaria.
  - database: contiene uno schema base per consentire l'avvio dell'applicativo Web
  - etc
      - cron.daily: contiene un job cron per l'aggiornamento quotidiano delle statistiche
      - init.d:        contiene gli script di avvio dei demoni python
  - log:             contiene i log generato dall'applicativo web e dai demoni
  - www:          contiene la parte applicativa web
      - tpl:           contiene i modelli (template) delle pagine web generate dall'applicazione
      - html:        l'applicativo web completo inclusi css e librerie javascript.

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
Per l'accesso dall'esterno, può essere utile usare HTTPS con mutua autenticazione. Questo limita l'utilizzo dell'applicazione ai soli dispositivi che hanno certificati client validi.

#### Note Tecniche
Una particolarità dell'approccio allo sviluppo di questo applicativo è proprio il modo in cui viene usato il DB, che è considerato parte integrante dell'applicazione stessa e non solo come "mero" contenitore di dati. Il funzionamento stesso dell'applicazione è strettamente legato al DB, che tramite funzioni e trigger si occupa di elaborare i dati. Postgres è stato scelto proprio per la grande flessibilità di manipolazione dei dati in arrivo tramite regole, funzioni e trigger.

## Installazione

Durante la fase di installazione si suppone che i sorgenti siano stati scaricati da GitHub e copiati localmente in una directory del Raspberry. Con `<smac>` viene indicata appunto questa directory.

Se, per esempio, i sorgenti del progetto sono stati scaricati nella home dell'utente standard `pi` del Rasperry, (`/home/pi`) sostituire `<smac>` con `/home/pi/smac`.

La procedura prevede l'installazione di un WebServer, del php dei driver pdo per postgresql e dello stesso database direttamente sul Raspberry. È tuttavia possibile separare i vari componenti installando sul Raspberry solo la parte degli eseguibili in Python.

Relativamente al webserver è possibile scegliere tra Apache (httpd) ed nginx, vengono infatti fornite le configurazioni di entrambi. Sicuramente **Ngnix** è più parco di risorse rispetto ad **Apache** pertanto sul Raspberry, si consiglia di installre il primo:

##### Creazione della directory del progetto

Tutti i file necessari vengono installati in

        mkdir /opt/smac

##### Installazione e configurazione del Webserver
Come anticipato vengono fornite le configurazioni di Ngnix e di Apache2. Se l'installazione è eseguita sul Raspberry si consiglia di installare il primo perchè è più leggero:

- **Ngnix**

    installazione webserver, php e librerie:

       sudo apt-get install nginx php5-cli php5-fpm php5-pgsql

    copia file di configurazione di Ngnix dalla directory del progetto:

        copiare dalla directory del progetto in `/opt/smac` la directory `ngnix`

        sudo cp -R <smac>/ngnix /opt/smac

    installazione della configurazione:

        sudo ln -s /opt/smac/ngnix/smac.conf /etc/ngnix/conf.d/smac.conf

- **Apache2**

    installazione webserver, php e librerie:

        sudo apt-get install httpd php5 php5-cli libapache2-mod-php5 php5-pgsql

    copia file di configurazione di Apache dalla directory del progetto:

        sudo cp -R <smac>/apache2 /opt/smac

   installazione della configurazione:

        sudo ln -s /opt/smac/apache2/smac.conf /etc/apache2/conf.d/smac.conf

    abilitazione del modrewrite:

        sudo a2enmod rewrite

- **Passi in Comune**
La creazione delle directory dei log sono in comune ad per entrambi i WebServer:

    sudo mkdir -p /opt/smac/log/

##### Installazione librerie python per il controllo GPIO

Per il controllo dei pin sul connettore GPIO l'applicativo utilizza la libreria python:

        sudo apt-get install python-rpi.gpio

##### Compilazione dei driver Adafruit Python
Per la lettura dei valori rilevati dai sensori di temperatura **DHT11** e **DHT22** viene utilizza la libreria di Adafruit_Python_DHT:

        cd <smac>/drivers/Adafruit_Python_DHT/
        python setup.py build
        python setup.py install

NOTA: Ho eseguito vari test sperimentali sui sensori DHTxx. Il sensore DHT22 è più preciso e stabile rispetto al DHT11. Entrambi comunque sono abbastanza sensibili alla distanza e se non viene usata correttamente una resistenza di "pull-up" di valore adeguato tra i pin dati e alimentazione, tendono a riportare risultati di temperatura/umidità completamente errati o fuori scala. Relatiavmente al sensore DHT11 ho notato che se si eseguono tre letture per ogni campionamento, i valori riportati sono più stabili e meno suscettibili ai predetti errori. Proprio per questo nel tempo ho modificato lo script python dhtxx.py in modo da effettuare tre letture ad intervalli di due (2) secondi ad ogni invocazione. Inoltre per migliorare l'affidabilità, vengono automaticamente scartati i valori fuori scala (esempio umidità > 100%) e ai valori ottenuti viene applicato il test Q o di Dixon per scartare eventuali valori che hanno una probabilità abbastanza alta di essere errati.


##### Installazione degli eseguibili python e dell'applicativo Web in php

Copiare in `/opt/smac` le seguenti directory da quella del progetto:

    bin, ect, www

Assicurarsi che tutti i file nella directory `bin` siano eseguibili e che i file della directory `www` appartengano all'utente del webserver generalmente `www-data`
    sudo chmod -R +x /bin
    sudo chown -R www-data /opt/smac/www
    sudo chown -R www-data /opt/smac/log

Installare i demoni ''SysVinit'': **collector**, **actuator**, **switcher**,  collegando semplicemente collegare gli script di gestione dalla directory `/opt/smac/etc/init.d/` in `/etc/init.d` e quindi abilitarli usando il comando `update-rc.d`:

        for daemon in collector actuator switcher; do
          sudo ln -s /opt/smac/etc/init.d/$daemon /etc/init.d/$daemon
          sudo update-rc.d -f $daemon remove;
          sudo update-rc.d -f $daemon defaults;
          sudo update-rc.d -f $daemon enable;
        done

##### Installazione, configurazione e importazione del Database

Installare il database server Postgresql

    sudo apt-get install postgresql

Abilitare l'utente `smac` per la connessione locale con password su "Linux Socket" (localhost) modificando il file pg_hba.conf. Nell'installazione standard tale file dovrebbe trovarsi in `/etc/postgresql/9.1/main`
Usado l'editor `vi`:

        sudo vi /etc/postgresql/9.1/main/pg_hba.conf

   Aggiungere la seguente riga:

        # TYPE  DATABASE        USER            METHOD
        local   smac            smac            password

Riaviare il database:

        sudo /etc/init.d/postgresql restart

Usare l'utente _postgresq_ per connettersi al database ed eseguire l'importazione dei dati.

        su - postgresq
        psql < "<smac>/postgres_database_schema.sql"

##### Configurazione cron
Uno script si occupa di generare le statistiche giornaliere relative alle misurazioni registrate dai sensori. È necessario che tale script venga pianificato giornalmente come job di cron affinchè le statiche vengano generate correttamente:

        chmod +x /opt/smac/etc/cron.daily/update_stats
        ln -s /opt/smac/etc/cron.daily/update_stats /etc/cron.daily/update_stats
