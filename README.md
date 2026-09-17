# GPTquote

Piccola app macOS da barra menu che mostra le quote rimanenti restituite dal Codex App Server ufficiale.

## Requisiti

- macOS 13 o successivo
- app ChatGPT/Codex aggiornata, oppure il comando `codex` installato in `/opt/homebrew/bin` o `/usr/local/bin`
- strumenti da riga di comando Swift di Apple

## Compilazione

```sh
./scripts/build-app.sh
open "dist/GPTquote.app"
```

Per verificare il parsing delle finestre di utilizzo:

```sh
./scripts/test.sh
```

Al primo avvio seleziona **Accedi con ChatGPT**. Il browser completa il flusso ufficiale e Codex conserva la credenziale nel Portachiavi macOS. L’app usa una propria cartella Codex separata da quella dell’app ChatGPT. Per compatibilità con le installazioni precedenti, il percorso interno rimane `~/Library/Application Support/GPT Usage Menu/Codex`.

Le quote vengono aggiornate ogni cinque minuti, all’avvio e su richiesta. La percentuale nella barra indica la quota primaria `codex`; il pannello mostra anche eventuali finestre o modelli aggiuntivi restituiti dall’account.

## Sorgente dati

L’app avvia localmente `codex app-server` tramite `stdio`, esegue l’handshake JSONL ufficiale e usa:

- `account/read` per lo stato dell’account;
- `account/login/start` per il login ChatGPT gestito da Codex;
- `account/rateLimits/read` per percentuali e reset;
- `account/rateLimits/updated` per gli aggiornamenti notificati dal servizio.

Non usa chiavi API, cookie del browser o endpoint ChatGPT privati.
