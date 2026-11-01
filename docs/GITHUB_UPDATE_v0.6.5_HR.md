# NEXUS OS v0.6.5 — kompletan test ažuriranja iz Minecrafta

**Početno stanje:** NEXUS v0.6.4 radi; GitHub Update Center vidi v0.6.4 i javlja `UP TO DATE`.

## 1. Objavi izdanje na GitHubu

Na Linuxu preuzmi ZIP, raspakiraj ga i kopiraj sadržaj u lokalnu mapu projekta `~/Downloads/NEXUS_OS`. U terminalu te mape pokreni:

```sh
git status --short
git add .
git commit -m "Release NEXUS OS v0.6.5 updater test"
git push origin main
```

Ažuriranje mora objaviti **zajedno** `dist/nexus.lua`, `update.nxs`, `update.json` i `dist/SHA256SUMS`. Ne objavljuj manifest odvojeno od Lua koda.

## 2. Prvo provjeri objavu

GitHub `main/update.nxs` mora prikazivati `version=0.6.5`. Lua datoteka `main/dist/nexus.lua` mora početi s `-- NEXUS OS Core v0.6.5` i `-- NEXUS-VERSION: 0.6.5`. Sva tri hasha (manifest, JSON, `SHA256SUMS`) moraju se podudarati.

## 3. Test u Minecraftu, bez izlaska u OpenOS

1. U NEXUS-u v0.6.4 otvori `[UPD]`.
2. Odaberi `CHECK GITHUB UPDATES` (mora pisati `GITHUB v0.6.5` te da je dostupna novija verzija).
3. Odaberi `DOWNLOAD GITHUB RELEASE`; očekuj `STAGED v0.6.5`.
4. Odaberi `INSTALL STAGED RELEASE` i potvrdi. NEXUS sprema staru verziju kao `previous.lua` i sam pokušava pokrenuti novu.
5. Provjeri `v0.6.5` u zaglavlju. Otvori File Manager ili System Center i vrati se na radnu površinu.
6. Opet otvori `[UPD]`, odaberi provjeru i očekuj `UP TO DATE`; `BACKUP YES` potvrđuje raspoloživu prethodnu verziju.
7. Ako želiš testirati reboot, izađi pravilno i ponovno pokreni Minecraft računalo tek kada je autostart ispravno postavljen. Reboot nije obvezan za test preuzimanja.

## 4. Ako nešto ne uspije

- `GitHub has no newer stable version`: provjeri manifest na GitHubu i da trenutna verzija i dalje piše v0.6.4.
- `SHA-256 mismatch` ili `size mismatch`: moguće je da je GitHub Raw privremeno vratio različite verzije datoteka zbog predmemorije. Ne preskači provjeru; ponovi nakon što se sadržaj objavljenog manifesta i Lua datoteke uskladi.
- `Download failed` ili `wget did not save file`: provjeri Internet Card i `wget` pristup GitHub Raw.
- `Pending update transaction`: nemoj brisati datoteke `transaction` i `previous.lua` napamet; sačuvaj poruku i postojeći OS.
- NEXUS se ne pokrene: u OpenOS-u koristi postojeći maintenance/recovery postupak; ne mijenjaj EEPROM ni OpenOS boot.

**Sigurnost:** SHA-256 pruža provjeru integriteta prema manifestu, ne digitalni potpis. Instalacija uvijek zahtijeva korisničku potvrdu.
