# Data assets

- `oui.tsv.gz` — MAC vendor prefixes (MA-L/MA-M/MA-S) extracted from the IEEE registry via Wireshark's `manuf` file (https://www.wireshark.org/download/automated/data/manuf). Regenerate occasionally; format is `HEXPREFIX<TAB>Vendor` per line, gzip-compressed.
