# Frontend Research

## Auslieferung Kartendaten an React
### Grundlagen
- API von Python (Flask) Backend
- React Frontend als separater "C4-Container"

### API
- Anfrage an API, welche Daten für einen bestimmten Parameter (z.B. Tag / Nacht) zur Verfügung stehen
- API antwortet mit links zu den entsprechenden Ressourcen (RESTful?)
- Auslieferung im GeoJSON format
    - Properties: Welche Güteklasse
- Braucht evtl. [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
    - [CORS mit Flask](https://pypi.python.org/pypi/Flask-Cors)

### Frontend
- API aufrufen mit [fetch() API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
    - Beispiel: <https://blog.hellojs.org/fetching-api-data-with-react-js-460fe8bbf8f2>
- Die API-Calls sind jeweils in den UI-Komponenten, die sie benötigen (in `componentWillMount()`)
- Wenn User Parameter auswählen möchte -> Anfrage an API nach Ressourcen
    - Bei Auswahl -> Anfrage an API nach konkretem GeoJSON, Map-Layer neu rendern

### Ideen
- Standardmässig die ÖV-Güteklassen als "fliessende" Heatmap anzeigen (Gütklassen von verschiedenen Haltestellen fliessen ineinander ohne Ränder)
- Wenn eine Haltestelle angeklickt wird, die konkreten Ränder des Einzugsgebiet anzeigen / hervorheben