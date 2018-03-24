# Frontend Research

## Auslieferung Kartendaten an React
### Grundlagen
- API von Python (Flask) Backend
- React Frontend als separater C4-Container

### API
- REST(-like?)
- Anfrage an API, welche Daten für einen bestimmten Parameter (z.B. Tag / Nacht) zur Verfügung stehen
- API antwortet mit links zu den entsprechenden Ressourcen
- Auslieferung im GeoJSON format
    - Properties: Welche Güteklasse
- Braucht evtl. [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
    - [CORS mit Flask](https://pypi.python.org/pypi/Flask-Cors)

### Frontend
- API aufrufen mit [fetch() API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
    - Beispiel: <https://blog.hellojs.org/fetching-api-data-with-react-js-460fe8bbf8f2>
- Abkapseln in Komponenten
- Wenn User Parameter auswählen möchte -> Anfrage an API nach Ressourcen
    - Bei Auswahl -> Anfrage an API nach konkretem GeoJSON, Map neu rendern