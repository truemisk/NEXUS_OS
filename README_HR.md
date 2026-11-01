# NEXUS OS v0.6.4 — GitHub Update Center

NEXUS je grafičko računalno okruženje za Minecraft OpenComputers, izgrađeno iznad OpenOS-a. Verzija **v0.6.4** dodaje ažuriranja preko GitHuba bez ovisnosti o Pastebinu.

- **Nova opcija:** provjera najnovije stabilne verzije preko GitHub Raw manifesta.
- **Sigurnost:** provjera SHA-256, veličine i Lua sintakse, sigurnosna kopija, potvrda instalacije i rollback.
- **Kompatibilnost:** postojeće aplikacije, GPU odabir i `/home/osv4.lua` ostaju isti.
- **Navigacija:** klikabilni HOME/BACK/EXIT i brojčani prečaci; nije potreban ESC ni F-tipke.
- **VAULT Storage:** nije dodan.

## Nadogradnja s v0.6.2 na v0.6.4

Najprije objavi v0.6.4 na GitHubu. Preuzmi distribuciju na OpenOS u `staged.lua`, a zatim koristi postojeći Update Center. Precizne naredbe i postupak opisani su u [uputama](docs/GITHUB_UPDATE_v0.6.4_HR.md).

Nakon instalacije, u Update Centeru otvori **CHECK GITHUB UPDATES**. Ako na GitHubu još piše v0.6.4, sustav treba prikazati da je ažuran. Kada kasnije objavimo v0.6.5, moći ćeš je preuzeti i instalirati iz istog ekrana bez ručnog preuzimanja preko terminala.

## Bitno

Ažuriranje je **ručno potvrđeno**, ne automatsko. SHA-256 provjerava podudarnost s manifestom, ali nije digitalni potpis. GitHub pristup uspješno je provjeren u OpenOS terminalu, no novu v0.6.4 grafičku funkciju tek treba testirati u Minecraftu.
