# smac
Smac Smart Raspberry/Arduino Clima System

L'applicativo si propone di implementare un sistema di monitoraggio e di controllo di un impianto di riscaldamento (caldaia) usando un dispositivo Rasperry.


Il repository cercherà di riprodurre al meglio la situazione che si dovrebbe ottenere a sitema funzionante. Cercherò inoltre di dare tutti i dettagli relativi per l'implementazione fisica del Raspberry e sensori.

L'applicativo in sè è composto da tre livelli

- Interfaccia Utente: l'interfaccia WEB scritta in PHP, tutte le librerie javascript (jquery, boostrap e plugin, sono già incluse nel repositori). L'interfaccia consente di impostare il funzionamento del sitema, monitoare tramite grafici l'andamento dei parametri ambientali, creare programmi e configurare i sensori collegati al dispositivo. Un altro requisito è un webserver. Nelle fasi iniziali è stato scelto Apache2 con vari moduli abilitati, tra cui il mod_rewrite per la riscrittura delle URL.

- Interfacciamento con l'Hardware: applicativi per lo più in python che si interfacciano con i sensori di teperatura/umidita (Work in progress) per raccogliere i dati ambientali.

- Il database. Nello specifico l'applicazione è stata scritta per funzionare esclusivamente con il DB Postgresl. Questo componente è parte integrante dell'applicazione, non solo ha il compito - ovvio - di conservare tutte le informazioni provenienti dai sensori e dall'interfaccia grafica, ma ha responsabilità di processare i dati.

Non è implementato alcun meccanismo di autenticazione/autorizzazione, ritengo che per applicativi di questo tipo non siano necessari, inoltre ho previsto l'utilizzo esclusivo di https con mutua autenticazione con certificati. In questo modo solo i dispositivi con certificati client validi potranno accedere alle pagine dell'applicativo.

Tutto questo ovviamente richiede una buona conoscenza sistemistica, ma proverò a fornire delle configurazioni minimali che consentano di avviare l'applicazione.

Una particolarità dell'approccio allo sviluppo di questo applicativo è proprio il modo in cui viene usato il DB, che è considerato parte integrante dell'applicazione stessa e non solo come "mero" contenitore di dati. Il funzionamento stesso dell'applicazione è strettamente legato al DB, che tramite funzioni e trigger si occupa di elaborare i dati. Postgres è stato scelto proprio per la grande flessibilità di manipolazione dei dati in arrivo tramite regole, funzioni e trigger.

Vengono forniti due dump del Database uno con dati fittizi l'altro il solo schema.

Prima di procedere all'importazione del database stesso è necessario creare l'utente "smac" è l'omonimo database, con i grant necessari:

    psql -U postgres

    create user smac
    create database smac
    grant all privileges on database smac to smac

Importare quindi uno dei due file del database:

psql -U smac smac < "nomefile.sql"




