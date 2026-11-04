# ClipPrint

**Copia. ⌃⌥⌘P. Stampato.**

Una piccola app per la barra dei menu di macOS che stampa quello che hai negli appunti. Niente da incollare in TextEdit, niente pagine da sistemare: copi un testo o una tabella da qualsiasi app, premi la scorciatoia e si apre il pannello di stampa di macOS con tutto già impaginato.

## Perché

Stampare un pezzo di pagina web, una mail o qualche riga di un foglio di calcolo su macOS vuol dire aprire un documento nuovo, incollare, sistemare i margini, togliere lo sfondo scuro, stampare e chiudere senza salvare. ClipPrint fa tutto questo con una scorciatoia.

## Cosa fa

- **Scorciatoia globale ⌃⌥⌘P** da qualsiasi app, oppure clic sull'icona nella barra dei menu → *Stampa appunti…*
- **Anteprima nel menu** di quello che stai per stampare.
- **Impaginazione A4** con margini di circa 2 cm.
- **Mantiene la formattazione** (grassetti, titoli, elenchi) e forza il testo in nero: anche se copi da un sito o un editor in modalità scura la stampa resta leggibile.
- **Tabelle vere.** Il testo separato da tab, cioè quello che ottieni copiando da Numbers, Excel, Google Fogli o da una tabella web, viene stampato come tabella con bordi e riga di intestazione.
- **Avvia al login**, attivabile dal menu.
- **Leggera.** Un solo file Swift, nessuna dipendenza, nessuna icona nel Dock.

## Installazione

Serve macOS 13 o successivo e la toolchain Swift (Xcode o Command Line Tools).

```sh
git clone https://github.com/alessiomicci/ClipPrint.git
cd ClipPrint
./build.sh install    # compila, copia in /Applications e avvia
```

Solo compilazione: `./build.sh` crea `build/ClipPrint.app`.

## Provare senza sprecare carta

```sh
.build/release/ClipPrint --pdf prova.pdf
```

Salva il contenuto degli appunti in PDF con la stessa impaginazione della stampa, senza aprire nessun pannello.

## Come funziona

ClipPrint guarda prima se il testo negli appunti ha la forma di una tabella: almeno due righe, tutte con lo stesso numero di colonne separate da tab. In quel caso lo trasforma in una `NSTextTable` con la prima riga come intestazione. Altrimenti usa la versione RTF, se c'è, oppure il testo semplice. Poi toglie gli sfondi, forza il testo in nero, lo impagina in una `NSTextView` e apre il pannello di stampa standard. La vista usa TextKit 1, perché TextKit 2 non disegna le tabelle `NSTextTable`.
