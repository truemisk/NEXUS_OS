# NEXUS OS v0.6.5 — test GitHub Update Centera

Ovo je malo testno izdanje verzije v0.6.4. Ne dodaje nove aplikacije i ne mijenja konfiguraciju, autostart, EEPROM ni OpenOS. Glavna svrha je stvarno testirati cjelokupni proces nadogradnje iz NEXUS-ova sučelja.

1. Objavi `dist/nexus.lua`, `update.nxs`, `update.json`, `dist/SHA256SUMS` i ostale priložene promjene na GitHub `main`.
2. U postojećem NEXUS-u v0.6.4 klikni `[UPD] > CHECK GITHUB UPDATES`. Treba prikazati v0.6.5.
3. Pokreni `DOWNLOAD GITHUB RELEASE`. Mora prikazati `STAGED v0.6.5` (provjeren SHA-256).
4. `INSTALL STAGED RELEASE` i potvrdi. Sustav treba sam ponovno pokrenuti NEXUS.
5. Provjeri `v0.6.5` u zaglavlju. Ponovno otvori `[UPD] > CHECK GITHUB UPDATES` i očekuj `UP TO DATE`.
6. Provjeri da je `BACKUP YES`, ali nemoj pokretati rollback ako sve radi.

Ako dođe do mrežne ili SHA-256 pogreške, nemoj zaobilaziti provjeru niti prepisivati `/home/osv4.lua`. Na GitHub Raw CDN-u može kratko kasniti osvježenje datoteka nakon pusha. Sačekaj da se obje datoteke ažuriraju, ponovno provjeri status i ponovi preuzimanje.

Više detalja: `docs/GITHUB_UPDATE_v0.6.5_HR.md`.
