# Lagertest Utrullning – systembeskrivning

Mobilwebbsida som mäter friktion i kartens hjul-/bakaxellager med ett utrullningstest.
Telefonen fästs på navet, hjulet snurras upp och får rulla ut fritt. Gyrot loggar vinkelhastigheten.

## Fysik
- Rörelseekvation vid fri utrullning: J·dω/dt = −T(ω).
- Modell: T(ω) = J·(a + b·ω). a = konstant friktion (lager, tätning, bromsdrag), b = hastighetsberoende (fett, luft).
- a och b fås ur linjär anpassning av −dω/dt mot ω i utrullningsdelen (mellan 95 % av toppvarvet och max(1,5 rad/s; 8 % av toppen)).
- ω = |gyrovektor|, så telefonens orientering och placering spelar ingen roll (stel kropp).
- Nyckeltal: T vid 15 rad/s (mNm), utrullningstid 25 → 5 rad/s, förlust vid 50 km/h P = T·ω (extrapolerat).
- Gyrot mättar typiskt vid ±2000 °/s ≈ 35 rad/s. Sidan varnar om platå nära toppen.

## Mätning av tröghetsmoment J (fallvikt)
- Snöre lindat runt däcket (radie r = uppmätt omkrets C / 2π), vikt m faller fritt och snöret släpper när det rullats av.
- Fallet: (J + m·r²)·α₁ = m·g·r − T_f. Fri utrullning direkt efter släpp: J·α₂ = T_f.
- Eliminera T_f: J = m·r·(g − r·α₁) / (α₁ + α₂).
- α₁: linjär anpassning av ω(t) mellan 15 % och 85 % av toppvarvet före toppen.
- α₂: linjär anpassning 0,3–2,8 s efter toppen (ned till 30 % av toppen). Godkänns om 0 < α₂ < 0,5·α₁, annars tas α₂ = a + b·(ω_topp/2) från senaste sparade utrullning, annars 0 med varning.
- Varningar: R² < 0,97 under fallet, toppvarv > 30 rad/s (gyromättning), snöret släppte inte.
- Senaste 10 J-värden sparas i localStorage; medel ± standardavvikelse av de 3 senaste med samma m och r visas. "Använd som J" skriver in värdet i inställningarna.
- Verifierat mot simulering med hastighetsberoende friktion: fel < 1,1 %.

## Signalbehandling
- Omsampling till 50 Hz med linjär interpolation, glidande medel över 9 punkter (0,18 s).
- Derivata: centraldifferens över ±5 punkter (0,2 s).
- Auto-stopp: armeras när ω > 8 rad/s i 0,5 s, stoppar när ω < 0,5 rad/s i 2 s. Maxlängd 240 s.

## Sensorer
- Android/Chrome: Generic Sensor API (Gyroscope, LinearAccelerationSensor) på 200 Hz begärt.
- iOS/Safari och övriga: DeviceMotionEvent (≈60 Hz), med tillståndsfråga på iOS.
- Kräver https (GitHub Pages).
- iOS: tillståndsfrågan måste anropas synkront i klickhändelsen (permNow()), annars avvisas den. Nekat tillstånd sitter kvar tills webbplatsdata för github.io rensas i Safari.

## Felsökning
- Separat ES5-skript överst loggar UA, https, standalone-läge, alla JS-fel och ohanterade löften, sensorkälla, tillståndssvar, första devicemotion-händelsen och antal sampel efter 2,5 s.
- Loggen visas under "Felsökning" och kopieras med "Kopiera logg". Om huvudskriptet inte startar inom 1,5 s loggas det som fel.

## Lagring
- IndexedDB i telefonens webbläsare (databas `lagertest`, store `runs`). Inställningar i localStorage.
- Export: CSV per körning (gyro + accelerometer), JSON med alla körningar. Import av JSON.
- Exporten öppnar systemets delningsmeny (navigator.share med File) där Google Drive kan väljas. JSON-exporten använder redan inlästa körningar så att delningen sker inom klickets användaraktivering (krav i iOS).
- iOS: Safari och hemskärmsappen har separat lagring. Safari kan rensa webbplatsdata efter ca 7 dagar utan besök, hemskärmsappar skyddas.

## Uppläggning
- `deploy-lagertest.bat` (kör `deploy-lagertest.ps1`): installerar git/gh, loggar in, skapar repo `kart-lagertest`, aktiverar Pages. Logg i `deploy-log.txt`.
- Adress: `https://<github-användare>.github.io/kart-lagertest/`

## Ändringslogg
Regel: systembeskrivningen uppdateras vid varje kodändring.
- 2026-10-23c: Export via delningsmenyn (Web Share API med filer) så att CSV/JSON kan sparas direkt i Google Drive eller annan app. Faller tillbaka på nedladdning om delning saknas. JSON-filnamn får datum och klockslag. Rekommenderad mappstruktur i Drive: Kart/Lagertest/Backup (JSON) och Kart/Lagertest/Rådata (CSV).
- 2026-10-23b: Safari-fix. Rörelsetillstånd (DeviceMotionEvent.requestPermission) begärs nu synkront i själva knapptrycket. Borttagen syntax som äldre Safari inte kan tolka (??=, dateStyle). Ny felsökningslogg på sidan (ES5-skript som fångar alla fel, sensorstatus, första sampel, antal sampel) med knapp för att kopiera loggen.
- 2026-10-23: J-mätning med fallvikt (friktionskompenserad i samma körning), medelvärde av 3 mätningar, knapp för att använda J.
- 2026-10-23: Första version. Utrullningsanalys, auto-stopp, lagring, jämförelse, CSV/JSON-export, uppläggningsskript.
