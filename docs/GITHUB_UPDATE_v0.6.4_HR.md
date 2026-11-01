# NEXUS OS v0.6.4 — GitHub Update Center: instalacija i testiranje

## Stanje prije instalacije

- Aktivni NEXUS u Minecraftu: **v0.6.2**, `/home/osv4.lua`.
- GitHub repozitorij: https://github.com/truemisk/NEXUS_OS
- GitHub Raw `wget` preuzimanje već je potvrđeno na korisnikovom OpenOS-u.
- ZIP sadrži datoteke za objavu na GitHub. **Samo lokalno testiranje nije dokaz da v0.6.4 već radi u Minecraftu.**

## Korak 1 — Objavi novi kod na GitHub

Na CachyOS-u preuzmi ZIP `NEXUS_OS_GitHub_Update_v0.6.4.zip` u `~/Downloads`. Izvuci sadržaj u privremenu mapu i kopiraj datoteke u postojeći lokalni repozitorij, bez brisanja `.git`:

```bash
cd ~/Downloads
unzip NEXUS_OS_GitHub_Update_v0.6.4.zip -d nexus64-upload
cp -a nexus64-upload/. NEXUS_OS/
cd NEXUS_OS
git status --short
git add .
git commit -m "NEXUS OS v0.6.4 GitHub Update Center"
git push origin main
```

Naredbe pretpostavljaju da repozitorij postoji na `~/Downloads/NEXUS_OS` i da su Git identitet i SSH već konfigurirani. Ako postoje lokalne promjene koje nisi namjeravao objaviti, provjeri `git diff` prije `git add .`.

Provjeri u pregledniku:

- https://github.com/truemisk/NEXUS_OS/blob/main/update.nxs
- https://github.com/truemisk/NEXUS_OS/blob/main/dist/nexus.lua

Manifest mora prikazivati `version=0.6.4` i SHA-256 koji se podudara s novom distribucijom.

## Korak 2 — Jednokratna nadogradnja preko OpenOS-a

**Nemoj prepisivati aktivni `/home/osv4.lua` iz terminala.** Koristi već funkcionalni sustav stage + install.

Zatvori NEXUS pomoću `[EXIT]` pa `[YES]`. U OpenOS-u provjeri ima li prethodni `staged.lua`. Ako postoji, sačuvaj ga:

```sh
mv /home/nexus/updates/staged.lua /home/nexus/updates/staged-old.lua
```

Ako datoteka ne postoji, ova naredba može javiti grešku; preskoči je.

Zatim preuzmi novi stabilni NEXUS **nakon uspješnog GitHub pusha**:

```sh
wget "https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua" /home/nexus/updates/staged.lua
```

Pokreni postojeći NEXUS:

```sh
/home/osv4.lua
```

Otvori `[UPD]` → `REFRESH STATUS`. Provjeri da jasno piše **STAGED v0.6.4**. Klikni `INSTALL STAGED RELEASE`, potvrdi `YES`. Nakon ponovnog prikaza desktopa provjeri oznaku **v0.6.4**.

Ako se prikaže problem s recoveryjem, nemoj brisati `previous.lua` ili `transaction`. Pošalji točnu poruku. Ova početna instalacija koristi postojeći mehanizam v0.6.2 i zbog toga još nema SHA-256 zaštitu novog GitHub instalera.

## Korak 3 — Provjeri novu GitHub funkciju

U v0.6.4 otvori `[UPD]` i odaberi:

1. `CHECK GITHUB UPDATES`: dohvat malog `update.nxs` manifesta s GitHuba.
2. Ako je GitHub na v0.6.4, očekuj informaciju da **nema novije verzije**.
3. `DOWNLOAD GITHUB RELEASE` neće zamijeniti aktivni OS ako nema novijeg izdanja.
4. `AUTOSTART` provjeri da koristi postojeći `/home/osv4.lua`. Ne moraš ga ponovno uključivati.
5. `BACK` i `HOME` moraju raditi klikom, bez ESC i F-tipki.

Kada kasnije objavimo sljedeću verziju, oba GitHub podatka (`update.nxs` i `dist/nexus.lua`) moraju se ažurirati zajedno. Tada klikni `CHECK GITHUB UPDATES`, `DOWNLOAD GITHUB RELEASE` i `INSTALL STAGED RELEASE` te potvrdi `YES`.

## Ako se pojavi SHA-256 greška

Nemoj instalirati preuzeto. GitHub Raw CDN ponekad kratko poslužuje staru kopiju jedne od dvije datoteke nakon objave. Pričekaj da se objavljeni manifest i datoteka usklade i ponovno provjeri. Ne isključuj provjeru integriteta.

## Sigurnost i ograničenja

- NEXUS dopušta samo stabilni GitHub Raw URL iz ovog repozitorija, a ne proizvoljni URL.
- SHA-256 je provjera podudarnosti, **ne** kriptografski potpis izdavača. Izmjena i manifesta i Lua datoteke može zaobići provjeru.
- NEXUS preuzima u privremenu datoteku, provjerava verziju, veličinu, sintaksu i hash prije staginga.
- Pri samoj instalaciji ponovno računa SHA-256 za GitHub staging.
- Instalacija zahtijeva izričitu potvrdu i zadržava `previous.lua` za rollback.
- Instalacijski floppy disk, VAULT Storage i zaseban kernel nisu dio ove faze.
