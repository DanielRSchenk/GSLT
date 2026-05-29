# Lua-woordafbreekalgoritme

Voor het vak *Green Software* heimplementeren we het interne woordafbreekalgoritme van TeX.
Dit maakt gebruik van een briljante datastructuur, waardoor het afbreken van woorden heel snel en dus energiezuinig verloopt.
Wij gaan dit algoritme op een naïeve manier nabouwen
om aan te tonen hoe goed het oorspronkelijke algoritme is.

## de bestanden

In de repo vind je de volgende bestanden:
- `hyphenation.lua` is het script dat TeX’s interne woordafbreekalgoritme vervangt door ons eigen naïeve implementatie.
- `hyph_en.dic` is een bestand met woordafbreekregels voor het Engels.

## runnen

Om het algoritme op het boek *On the Origin of Species* van Darwin te runnen:
- Kies welk afbreekalgoritme je wilt gebruiken in `config.lua`. (Zie onder het kopje *configureren* hieronder.)
- Compileer het document met `lualatex`:
    ```
    lualatex darwin.tex
    ```

Om het algoritme op een ander TeX-document te runnen:
- Voeg deze regel toe in de preamble van het document:
    ```tex
    \directlua{dofile("hyphenation.lua")}
    ```
- Zorg dat `hyphenation.lua` en `hyph_en.dic` in dezelfde map zitten als het TeX-document.
- Kies welk afbreekalgoritme je wilt gebruiken in `config.lua`.
- Compileer het document met `lualatex`:
    ```
    lualatex [documentnaam].tex
    ```

Je kunt ook het programmaatje los runnen in de interactieve modus:
```
lua -i hyphenation.lua
```

En dan kun je losse woorden afbreken. Typ bijvoorbeeld in:
```
hyp('sustainability')
```

Dan krijg je dit:
```
-----------------------------
         a i2
         a4i4n
                1b i l
                 b i l1i
                   i l1i
                  2i l1i t
           i1n a
                     l1i t
            1n a
            2n1a2b
     s1t a
1s u
      1t a
       t a i2
                        1t y
  2u s
=============================
1s2u s1t a4i4n1a2b2i l1i1t y 
 s u s·t a i n·a b i l·i·t y 
-----------------------------
 sus·tain·abil·i·ty
-----------------------------
```

## configureren

In `config.lua` kun je de variabele `algorithm` een waarde geven: `0`, `1` of `2`. Dit bepaalt welk woordafbreekalgoritme wordt gebruikt:

- `0`: geen woordafbreking.
- `1`: het snelle ingebouwde woordafbreekalgoritme van TeX.
- `2`: onze trage naïeve herimplementatie ervan.

