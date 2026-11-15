# Cómo conectar la simulación con Firebase

La idea es que **la simulación escribe** en Firebase cada vez que cambia algo y **la app solo escucha**.
Así las dos muestran siempre lo mismo y nunca se pisan.

Todo el cambio va en un solo archivo: `scripts/main.gd`. No hace falta instalar nada en Godot.
Funciona también en la versión web, porque usa la API REST de Firestore (es una llamada por internet normal).

---

## 1. En Firebase (Firestore)

**Reglas.** La simulación es una página pública y no tiene usuario, así que necesita permiso para escribir **solo** en esta colección.
En Firestore → Reglas, agrega esto dentro de `match /databases/{database}/documents { ... }`:

```
match /simulation_controls/{doc} {
  allow read, write: if true;
}
```

Deja cerradas las demás colecciones. Esta regla abierta está bien para la hackathon, no para producción.

**Qué se va a escribir.** Un solo documento: `simulation_controls/active_scenario`, con estos campos:

| Campo | Tipo | Ejemplo |
|---|---|---|
| `scenario` | texto | `normal`, `warning`, `solarFlare` o `hypoxia` |
| `stage` | número entero | `3` (de 1 a 8) |
| `stage_name` | texto | `ÓRBITA TERRESTRE` |
| `g` | número | `0.2` |
| `speed_kmh` | número | `27670` |
| `distance_km` | número | `185` |
| `updated_at` | fecha | hora del último cambio |

Los nombres de `scenario` tienen que ser **exactamente** iguales a los de tu app (mayúsculas incluidas).

---

## 2. En `scripts/main.gd`

**a) Arriba, junto a las otras constantes** (por ejemplo debajo de `const ASTRO_SCRIPT`), pega esto y pon el ID de tu proyecto:

```gdscript
const FIREBASE_PROJECT := "TU_PROJECT_ID"   # Configuración del proyecto en Firebase → ID del proyecto
const SYNC_EVERY := 2.0                     # cada cuántos segundos manda los números aunque no cambie el estado
var sync_t := 0.0
```

**b) Agrega esta función** (por ejemplo debajo de la función `_scenario`):

```gdscript
## Manda el estado actual a Firestore: simulation_controls/active_scenario
func _push_state() -> void:
	if FIREBASE_PROJECT == "TU_PROJECT_ID":
		return
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/simulation_controls/active_scenario" % FIREBASE_PROJECT
	var body := {
		"fields": {
			"scenario": {"stringValue": scenario},
			"stage": {"integerValue": str(stage + 1)},
			"stage_name": {"stringValue": STAGES[stage].name},
			"g": {"doubleValue": snappedf(tel_g, 0.1)},
			"speed_kmh": {"doubleValue": round(tel_v)},
			"distance_km": {"doubleValue": round(tel_d)},
			"updated_at": {"timestampValue": Time.get_datetime_string_from_system(true) + "Z"},
		}
	}
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, _body):
		if code != 200:
			push_warning("Firebase respondió %d" % code)
		req.queue_free())
	req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PATCH, JSON.stringify(body))
```

**c) Llámala en tres lugares:**

1. Dentro de `_scenario(s)`, al final (después de `astro.state = s`):
   ```gdscript
   	_push_state()
   ```
2. Dentro de `_enter(i)`, al final de la función (después del `match i:`), para avisar el cambio de etapa:
   ```gdscript
   	_push_state()
   ```
3. Dentro de `_process(dt)`, al principio (después de `clock += dt`), para mandar los números cada 2 segundos:
   ```gdscript
   	sync_t += dt
   	if sync_t >= SYNC_EVERY:
   		sync_t = 0.0
   		_push_state()
   ```

**Probar:** corre el proyecto con F5 y mira en la consola de Firebase cómo cambia el documento `active_scenario`.
Si en la salida de Godot aparece `Firebase respondió 403`, son las reglas. Si sale `404`, revisa el ID del proyecto.

---

## 3. En tu app: escuchar el documento

Web (Firebase v9 o superior):

```js
import { doc, onSnapshot } from "firebase/firestore";

onSnapshot(doc(db, "simulation_controls", "active_scenario"), (snap) => {
  const d = snap.data();
  // d.scenario, d.stage, d.stage_name, d.g, d.speed_kmh, d.distance_km
});
```

Android (Kotlin):

```kotlin
Firebase.firestore.collection("simulation_controls").document("active_scenario")
    .addSnapshotListener { snap, _ ->
        val scenario = snap?.getString("scenario")
        // ...
    }
```

---

## 4. Volver a publicar la versión web

El link (`https://thonyferriel05.github.io/spacesapps/`) muestra lo que está en la carpeta `docs/`. Después de cambiar el código:

1. En Godot: **Editor → Manage Export Templates → Download and Install** (solo la primera vez).
2. **Project → Export**. Ya hay un preset llamado **Web** que exporta a `docs/index.html`, con "Thread Support" apagado (así funciona en GitHub Pages).
3. **Export Project** → guarda en `docs/index.html` → desmarca "Export With Debug".
4. Haz commit y push. En un minuto el link ya tiene la versión nueva.
