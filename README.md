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

Sotto le quote, il pannello offre lo switch **Lancetta** per scegliere fra percentuale precisa e indicatore a tachimetro. Lo switch **Colori** è sempre disponibile: abilita le soglie verde (67–100%), giallo (34–66%) e rosso (0–33%) sia per il tachimetro sia per le percentuali; disattivandolo l’indicatore è monocromatico.

## Sorgente dati

L’app avvia localmente `codex app-server` tramite `stdio`, esegue l’handshake JSONL ufficiale e usa:

- `account/read` per lo stato dell’account;
- `account/login/start` per il login ChatGPT gestito da Codex;
- `account/rateLimits/read` per percentuali e reset;
- `account/rateLimits/updated` per gli aggiornamenti notificati dal servizio.

Non usa chiavi API, cookie del browser o endpoint ChatGPT privati.

## Credits

GPTquote è sviluppata da **Michele Stival** per **Archetipi Digitali**.

- Sito: [archetipi-digitali.it](https://www.archetipi-digitali.it)

## Licenza

Il codice sorgente è distribuito con licenza [Apache License 2.0](LICENSE).
I loghi e gli altri materiali di branding in `AppResources` sono esclusi
dalla licenza del codice; per i dettagli vedere [NOTICE](NOTICE).
