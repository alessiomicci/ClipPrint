# ClipPrint

App per la barra dei menu di macOS che stampa il testo negli appunti.

- **⌃⌥⌘P** da qualsiasi app (o clic sull'icona → "Stampa appunti…") apre il pannello di stampa di macOS.
- Impaginazione A4, margini ~2 cm; mantiene la formattazione RTF, testo sempre nero.
- Il testo separato da tab (tabelle copiate da web, Numbers, Excel, Fogli) viene stampato come tabella con bordi e intestazione.
- "Avvia al login" dal menu.

## Build

```sh
./build.sh            # crea build/ClipPrint.app
./build.sh install    # la copia in /Applications e la avvia
```

Verifica senza stampare: `.build/release/ClipPrint --pdf out.pdf` salva gli appunti in PDF.

Requisiti: macOS 13+, Xcode / Swift toolchain.
