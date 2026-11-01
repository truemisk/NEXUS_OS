# NEXUS OS v0.6.2 — Update Center + Hardware Center popravak

Ovo je nadogradnja s v0.6.0 na v0.6.2. Ne mijenja OpenOS, EEPROM niti postojeće postavke autostarta. Aktivna putanja ostaje `/home/osv4.lua`.

## Što je ispravljeno

1. **Update Center:** prvo pokušava preuzeti objavu kroz isti OpenOS `pastebin get` program koji već radi iz terminala. Ako naredba nije dostupna ili ne spremi datoteku, pokušava postojeći `internet.request()` način. Niti jedna preuzeta datoteka ne izvršava se prije provjere zaglavlja, verzije, Lua sintakse i veličine.
2. **Transakcije:** nakon što nova radna površina uspješno nacrta prvi kadar i provjeri aktivnu Lua datoteku, uklanja se oznaka probne instalacije. To dopušta sljedeći update tijekom iste sesije. Ne priznaje se pogrešna ili neusklađena transakcija.
3. **Hardware Center:** `component.list()` može vraćati pozivljivu tablicu (umjesto obične Lua funkcije). Popis uređaja i statusni brojač sada podržavaju oba oblika.
4. **Poruke o grešci:** uključuju korisniju dijagnostiku ako oba mrežna načina zakažu.

## Prva instalacija popravka (još uvijek v0.6.0)

1. Prenesi `NEXUS_OS_Update_Repair_v0.6.2.lua` na Pastebin i kopiraj samo ID objave.
2. Zatvori NEXUS kroz `[EXIT]` i potvrdi `YES`.
3. U OpenOS terminalu pokreni:

   ```sh
   pastebin get NOVI_ID /home/nexus/updates/staged.lua
   ```

   Ako već postoji `staged.lua`, najprije je preimenuj u `staged-old.lua` pomoću `mv`, a zatim ponovi naredbu.
4. Pokreni `/home/osv4.lua` i otvori `[UPD]`.
5. Klikni `REFRESH STATUS` i provjeri **STAGED v0.6.2**.
6. Tek tada klikni `INSTALL STAGED RELEASE` i potvrdi `YES`.
7. Provjeri prikazuje li zaglavlje **v0.6.2**, te u `[HW]` je li popis uređaja sada vidljiv.

Ova instalacija radi preko već testiranog staging sustava, bez ručne zamjene aktivne `osv4.lua` datoteke. Ne briši `previous.lua` ni `transaction` ako se pojavi greška; sačuvaj ispis i provjeri stanje prije ponovnog pokušaja.

## Test potpuno grafičkog ažuriranja

1. Objavi **drugu** datoteku `NEXUS_OS_Update_Test_v0.6.3.lua` na zaseban Pastebin ID. Nemoj objaviti izvorni v0.6.1 testni paket iz starije faze.
2. Unutar v0.6.2 otvori `[UPD] > DOWNLOAD FROM PASTEBIN`.
3. Upiši samo ID v0.6.3 objave (ne cijelu poveznicu) i pritisni Enter.
4. Provjeri prikazuje li **STAGED v0.6.3**.
5. Potvrdi `INSTALL STAGED RELEASE` te provjeri novo zaglavlje **v0.6.3**.

Ako se pojavi poruka greške, zapiši ili uslikaj njezin točan tekst. Nemoj odmah pritiskati `ROLL BACK` ili `RECOVER` bez provjere.

## Ograničenja i sigurnost

- Lokalni testovi ne potvrđuju da OpenOS naredba za Pastebin radi unutar tvoje konkretne Minecraft GUI sesije. To je potrebno potvrditi testom.
- Internet Card mora biti dostupan i Pastebin mora dopustiti pristup.
- Ažuriranja nisu kriptografski potpisana: preuzimaj samo vlastiti ili pouzdani ID objave.
- Preuzimanje se sprema u `/home/nexus/updates/download.part`; aktivni OS ne prepisuje se dok ne potvrdiš instalaciju.
- `previous.lua` je rezervna kopija za rollback; ne briši je.
- Ako se popis hardvera ne prikaže ni na v0.6.2, potrebno je provjeriti točnu OpenOS komponentnu implementaciju na stvarnom računalu.
