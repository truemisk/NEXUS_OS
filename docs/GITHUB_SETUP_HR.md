# NEXUS OS — postavljanje na GitHub (HR)

Repozitorij: https://github.com/truemisk/NEXUS_OS  
Grana: `main`  
Početna stabilna verzija: `0.6.2`

## Prvo učitavanje

Paket sadrži strukturu repozitorija i ne sadrži `.git` mapu. **Nemoj učitati ZIP kao jednu datoteku**: GitHub treba vidjeti pojedinačne mape i datoteke.

### Opcija A — Linux terminal (preporučeno)

Raspakiraj ZIP u zasebnu mapu. Zatim u terminalu na Linuxu:

```bash
git clone https://github.com/truemisk/NEXUS_OS.git
cp -a /PUTANJA/DO/RASPAKIRANOG/NEXUS_OS_GitHub_Starter_v0.6.2/. NEXUS_OS/
cd NEXUS_OS
git add .
git commit -m "Import NEXUS OS v0.6.2 and release metadata"
git push origin main
```

`PUTANJA/DO/RASPAKIRANOG` prilagodi svojoj mapi. GitHub će možda zatražiti prijavu u pregledniku, SSH ili token. Nemoj slati pristupne tokene u ChatGPT.

### Opcija B — GitHub web

U `NEXUS_OS` izaberi **Add file → Upload files**, prenesi sadržaj raspakiranog projekta i potvrdi commit. Ako preglednik ne očuva strukturu mapa, upotrijebi Linux terminal ili GitHub Desktop.

## Prva provjera nakon objave

Na GitHubu provjeri:

- `dist/nexus.lua` postoji i prva linija navodi v0.6.2
- `src/nexus/` sadrži modularne Lua datoteke
- `update.nxs` i `update.json` imaju verziju 0.6.2

Zatim unutar OpenOS-a možeš provjeriti mrežni pristup bez mijenjanja aktivnog OS-a:

```sh
wget "https://raw.githubusercontent.com/truemisk/NEXUS_OS/main/dist/nexus.lua" /home/nexus-github-test.lua
```

Provjeri datoteku `nexus-github-test.lua`; **nemoj** je automatski instalirati.

## Sadašnje ograničenje

NEXUS v0.6.2 još nema GitHub Update Center. `update.nxs` i `update.json` su početna shema koju sljedeća verzija treba podržati. Sve dok nije implementirana, ostaje prethodni način ažuriranja pomoću staging datoteke.

## Sigurnost i izvori

SHA-256 stabilnog izdanja: `402717913b58adce0e19e759aef787aa9f5e322b714c82300b69386232e5d58d`. Integritet provjerava ima li datoteka točne bajtove, ali sam hash na istom poslužitelju ne zamjenjuje digitalni potpis. U novoj implementaciji spriječit ćemo downgrade, provjeriti veličinu, oznaku distribucije, sintaksu i potvrdu korisnika te ostaviti rollback.
