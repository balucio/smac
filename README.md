# smac

Smac - Smart Raspberry/Arduino Clima System

Si osservi che il progetto è ancora in uno stato embrionale pertanto alcune caratteristiche potrebbero essere modificate nel tempo.

Il presente documento dovrebbe rispecchiare lo stato finale dell'applicazione.

-

L'applicativo si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento con caldaia usando un dispositivo Rasperry.

A progetto terminato il repository conterrà tutto l'occorrente per poter installare l'applicativo su tale dispositivo:

- Codice PHP (versione supportata 5.5)
- Dump iniziale del DB (supportato al momento solo Postgresql versione 8.5 e 9.X)
- Configurazione base di Apache (httpd), incluso mod_rewrite
- Schemi di collegamento sensori (per le misurazioni) e Relè (per il controllo della caldaia)

Logicamente l'applicazione è suddivisa nei seguenti blocchi:

- Interfaccia Utente:

Si tratta di un'interfaccia WEB, scritta principalmente in PHP. Lato client sono usate alcune librerie javascript (jquery, boostrap e plugin), incluse nel presente repository.

Tramite interfaccia è possibile:

    - controllare lo stato del sistema (accenzione, spegnimento, scelta programmi)
    - definire un programma (temperature di riferimento, giorni e orari di applicazione)
    - aggiungere un sensore (al momento sono supportati sensori DH11 e DH22 con misure di temperatura e umidità)
    - configurare parametri di base: temperatura anticongelamento, temperatura in caso di funzionamento manuale
    - visualizzare l'andamento dei dati atmosferici (al momento solo temperatura e umidità) rilevati dai sensori

- Interfacciamento con l'Hardware:

Un insieme di script per lo più in python che si interfacciano con i sensori e relè. Usati sia per raccogliere i dati di teperatura/umidita dai sensori, sia per accedendere e spegnere la caldaia in base alla programmazione impostata.

- Il database.

Al momento l'applicazione supporta esclusivamente il DB Postgresl. Sono forniti gli script di importazione per la versione 9.x e la versione 8.5.x. Per progetto questo componente è parte integrante dell'applicazione, non ha solo il compito - ovvio - di conservare tutte le informazioni provenienti dai sensori e dall'interfaccia grafica, ma gioca un ruolo abbastanza importante nell'elaborazione dei dati. Tali funzionalità sono state realizzate usando trigger, stored procedure e regole.

-

L'applicativo in sè non prevede alcun meccanismo di autenticazione/autorizzazione - non ritengo che per applicativi di questo tipo siano necessari.

Vengono forniti comunque una serie di script e file di configurazione per configurare Apache in HTTPS con muutua autenticazione. Questo limita l'utilizzo dell'applicazione ai soli dispositivi che hanno certificati client validi.

Una particolarità dell'approccio allo sviluppo di questo applicativo è proprio il modo in cui viene usato il DB, che è considerato parte integrante dell'applicazione stessa e non solo come "mero" contenitore di dati. Il funzionamento stesso dell'applicazione è strettamente legato al DB, che tramite funzioni e trigger si occupa di elaborare i dati. Postgres è stato scelto proprio per la grande flessibilità di manipolazione dei dati in arrivo tramite regole, funzioni e trigger.

-

Creazione del Database

Prima di procedere all'importazione del database stesso è necessario creare l'utente "smac" è l'omonimo database, con i grant necessari:

    psql -U postgres

    create user smac
    create database smac
    grant all privileges on database smac to smac

Importare quindi uno dei due file del database:

psql -U smac smac < "nomefile.sql"




