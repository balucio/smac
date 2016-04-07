# smac

Smac - Smart Raspberry/Arduino Clima System

Si osservi che il progetto è ancora in uno stato embrionale pertanto alcune caratteristiche potrebbero essere modificate nel tempo.

Il presente documento dovrebbe rispecchiare lo stato finale dell'applicazione.

L'applicativo si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento con caldaia usando un dispositivo Rasperry.

A progetto terminato il repository conterrà tutto l'occorrente per poter installare l'applicativo su tale dispositivo:

- Codice PHP (versione supportata 5.5)
- Database con schema e dati minimali che consentano il funzionamento iniziale dell'applicativo. Al momento è supportato solo Postgresql versione 9.X.
- Configurazione base del webserver Apache (httpd).
- Schemi di collegamento sensori (per le misurazioni) e del Relè (per il controllo della caldaia)

-

Logicamente l'applicazione è suddivisa nei seguenti blocchi:

- Interfaccia Utente:

Si tratta di un'interfaccia WEB, scritta in PHP. Lato client sono usate alcune librerie javascript (jquery, boostrap e plugin). Tutto l'occorrente è incluso nel repository.

Tramite interfaccia è possibile:

- controllare lo stato del sistema (accenzione, spegnimento, scelta programmi)
- definire un programma (temperature di riferimento, giorni e orari di applicazione)
- aggiungere un sensore (al momento sono supportati sensori DH11 e DH22 con misure di temperatura e umidità)
- configurare parametri di base: temperatura anticongelamento, temperatura in caso di funzionamento manuale
- visualizzare l'andamento dei dati atmosferici (al momento solo temperatura e umidità) rilevati dai sensori

- Il database.

Al momento l'applicazione supporta esclusivamente il DB Postgresl. È fornito lo script di importazione per la versione 9.x. Il database è parte fondamentale di Smac; non ha solo il compito - ovvio - di conservare tutte le informazioni provenienti dai sensori e dall'interfaccia grafica, ma gioca un ruolo molto importante nell'elaborazione dei dati. Gran parte dell'applicazione infatti utilizza stored procedure per leggere o scrivere i dati. Inoltre un triggere si preoccupa dell'elaborazione dei dati provenienti dai sensori.

- Interfacciamento con l'Hardware:

Si tratta di un insieme di script per lo più in python che si interfacciano con i sensori e relè. Usati sia per raccogliere i dati di teperatura/umidita dai sensori, sia per accedendere e spegnere la caldaia in base alla programmazione impostata.

Al momento sono supportati i sensori DHT11 e DHT22.
Il Relè che si occupa del controllo della caldaia è direttamente controllato tramite un pin dell'interfaccia GPIO. La scelta del PIN può essere effettuata nella pagina di impostazioni dell'interfaccia Web.

Ci sono vari componenti software che si preoccupano di gestire l'hardware:

- Collector: uno script python la cui esecuzione è pianificata in CRON ogni minuto che per ogni "Sensore" attivo, in base al driver (DHT11 o DHT22) e ai parametri impostati (PIN GPIO) legge i dati di temperatura e umidità e li scrive sul database

- Switcher: un demone python che controllando PIN GPIO del relè accende o spegne la caldaia. Lo switcher reagisce ad alcuni segnali:
    - on : attiva il relè chiudendo il circuito e accendendo la caldaia
    - off: disattiva lo stato del relè aprendo il circuito e spegnendo la caldaia
    - status: riporta lo stato del relè (on oppure off)
    - reload: ricarica la configurazione del relè

- Actuator: uno script python la cui esecuzione è pianificata ogni due minuti che in base al programma impostato, e ai dati del sensore di riferimento, accende o spegne la caldaia inviando sengali allo "Switcher";

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
