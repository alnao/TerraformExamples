# 📘 Documentazione API - Gestione Annotazioni

> **Versione**: 0.0.2  
> **Base URL**: `http://localhost:8080`  
> **Autenticazione**: JWT Bearer Token  
> **Content-Type**: `application/json`

---

## 📋 Indice

1. [Introduzione](#introduzione)
2. [Autenticazione](#autenticazione)
3. [API Annotazioni](#api-annotazioni)
4. [Modelli Dati](#modelli-dati)
5. [Codici di Stato](#codici-di-stato)
6. [Esempi Pratici](#esempi-pratici)

---

## 🎯 Introduzione

Questa documentazione descrive tutte le API REST esposte dal sistema di Gestione Annotazioni. Le API permettono di:

- Autenticarsi (login locale o OAuth2)
- Gestire annotazioni (CRUD completo)
- Prenotare annotazioni per modifica esclusiva
- Gestire transizioni di stato delle annotazioni
- Cercare e filtrare annotazioni

### Caratteristiche Principali

- **Autenticazione JWT**: Token con validità 24 ore
- **Lock Ottimistico**: Prenotazione annotazioni per evitare conflitti
- **Validazione Automatica**: Tutti i dati vengono validati automaticamente
- **CORS Abilitato**: Le API sono accessibili da qualsiasi origine
- **Swagger UI**: Documentazione interattiva disponibile su `/swagger-ui.html`

---

## 🔐 Autenticazione

### Base URL
```
/api/auth
```

### 1. Login Locale

**Endpoint**: `POST /api/auth/login`

Autentica un utente con username e password.

**Request Body**:
```json
{
  "username": "string",
  "password": "string"
}
```

**Response** (200 OK):
```json
{
  "token": "eyJhbGciOiJIUzUxMiJ9...",
  "tokenType": "Bearer",
  "username": "mario.rossi",
  "email": "mario@example.com",
  "accountType": "LOCAL",
  "role": "USER",
  "expiresIn": 86400
}
```

**Errori**:
- `401 Unauthorized`: Credenziali non valide
- `500 Internal Server Error`: Errore del server

**Esempio cURL**:
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "mario.rossi",
    "password": "password123"
  }'
```

---

### 2. Registrazione

**Endpoint**: `POST /api/auth/register`

Crea un nuovo account utente.

**Request Body**:
```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "firstName": "string",
  "lastName": "string"
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "username": "mario.rossi",
  "email": "mario@example.com",
  "firstName": "Mario",
  "lastName": "Rossi",
  "accountType": "LOCAL",
  "role": "USER",
  "enabled": true,
  "createdAt": "2025-11-27T10:00:00",
  "lastLogin": null
}
```

**Errori**:
- `400 Bad Request`: Dati non validi
- `409 Conflict`: Username o email già esistenti

---

### 3. Profilo Utente

**Endpoint**: `GET /api/auth/me`

Ottiene il profilo dell'utente autenticato.

**Headers Richiesti**:
```
Authorization: Bearer {token}
```

**Response** (200 OK):
```json
{
  "id": "uuid",
  "username": "mario.rossi",
  "email": "mario@example.com",
  "firstName": "Mario",
  "lastName": "Rossi",
  "accountType": "LOCAL",
  "role": "USER",
  "enabled": true,
  "createdAt": "2025-11-27T10:00:00",
  "lastLogin": "2025-11-27T15:30:00"
}
```

---

### 4. Refresh Token

**Endpoint**: `POST /api/auth/refresh`

Rinnova il token JWT.

**Headers Richiesti**:
```
Authorization: Bearer {old_token}
```

**Response** (200 OK):
```json
{
  "token": "eyJhbGciOiJIUzUxMiJ9...",
  "tokenType": "Bearer",
  "expiresIn": 86400
}
```

---

### 5. Logout

**Endpoint**: `POST /api/auth/logout`

Invalida tutti i token dell'utente.

**Headers Richiesti**:
```
Authorization: Bearer {token}
```

**Response** (200 OK): Nessun contenuto

---

### 6. Provider OAuth2

**Endpoint**: `GET /api/auth/providers`

Lista dei provider OAuth2 disponibili.

**Response** (200 OK):
```json
[
  {
    "id": "google",
    "name": "Google",
    "authorizationUrl": "/oauth2/authorization/google"
  },
  {
    "id": "github",
    "name": "GitHub",
    "authorizationUrl": "/oauth2/authorization/github"
  },
  {
    "id": "microsoft",
    "name": "Microsoft",
    "authorizationUrl": "/oauth2/authorization/microsoft"
  }
]
```

---

## 📝 API Annotazioni

### Base URL
```
/api/annotazioni
```

**Tutte le richieste richiedono il token JWT nell'header**:
```
Authorization: Bearer {token}
```

---

### 1. Crea Annotazione

**Endpoint**: `POST /api/annotazioni`

Crea una nuova annotazione.

**Request Body**:
```json
{
  "valoreNota": "string (1-10000 caratteri, obbligatorio)",
  "descrizione": "string (1-500 caratteri, obbligatorio)",
  "utente": "string (1-100 caratteri, obbligatorio)",
  "categoria": "string (max 100 caratteri, opzionale)",
  "tags": "string (max 500 caratteri, opzionale)",
  "pubblica": boolean (default: false),
  "priorita": integer (default: 1)
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "versioneNota": "1.0",
  "valoreNota": "Contenuto della nota",
  "descrizione": "Descrizione breve",
  "utenteCreazione": "mario.rossi",
  "dataInserimento": "2025-11-27T10:00:00",
  "dataUltimaModifica": "2025-11-27T10:00:00",
  "utenteUltimaModifica": "mario.rossi",
  "categoria": "Lavoro",
  "tags": "importante, urgente",
  "pubblica": false,
  "priorita": 1,
  "stato": "INSERITA"
}
```

**Errori**:
- `400 Bad Request`: Dati non validi

---

### 2. Ottieni Tutte le Annotazioni

**Endpoint**: `GET /api/annotazioni`

Recupera tutte le annotazioni.

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "versioneNota": "1.0",
    "valoreNota": "...",
    "descrizione": "...",
    ...
  }
]
```

---

### 3. Ottieni Annotazione per ID

**Endpoint**: `GET /api/annotazioni/{id}`

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Response** (200 OK):
```json
{
  "id": "uuid",
  "versioneNota": "1.0",
  ...
}
```

**Errori**:
- `404 Not Found`: Annotazione non trovata

---

### 4. Aggiorna Annotazione

**Endpoint**: `PUT /api/annotazioni/{id}`

Aggiorna un'annotazione esistente. **Richiede il lock acquisito**.

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Request Body**:
```json
{
  "valoreNota": "string",
  "descrizione": "string",
  "utente": "string",
  "categoria": "string",
  "tags": "string",
  "pubblica": boolean,
  "priorita": integer
}
```

**Response** (200 OK):
```json
{
  "id": "uuid",
  "versioneNota": "1.1",
  ...
}
```

**Errori**:
- `404 Not Found`: Annotazione non trovata
- `409 Conflict`: Annotazione bloccata da altro utente

---

### 5. Elimina Annotazione

**Endpoint**: `DELETE /api/annotazioni/{id}`

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Response** (204 No Content): Nessun contenuto

---

### 6. Cerca Annotazioni

**Endpoint**: `GET /api/annotazioni/cerca`

Cerca annotazioni per testo (full-text search).

**Query Parameters**:
- `testo` (string, obbligatorio): Testo da cercare

**Esempio**:
```
GET /api/annotazioni/cerca?testo=urgente
```

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    ...
  }
]
```

---

### 7. Filtra per Utente

**Endpoint**: `GET /api/annotazioni/utente/{utente}`

**Path Parameters**:
- `utente` (string, obbligatorio): Nome utente

**Response** (200 OK): Array di annotazioni

---

### 8. Filtra per Categoria

**Endpoint**: `GET /api/annotazioni/categoria/{categoria}`

**Path Parameters**:
- `categoria` (string, obbligatorio): Nome categoria

**Response** (200 OK): Array di annotazioni

---

### 9. Filtra per Stato

**Endpoint**: `GET /api/annotazioni/stato/{stato}`

**Path Parameters**:
- `stato` (string, obbligatorio): Uno tra:
  - `INSERITA`
  - `MODIFICATA`
  - `CONFERMATA`
  - `RIFIUTATA`
  - `DAINVIARE`
  - `INVIATA`
  - `SCADUTA`
  - `BANNATA`
  - `ERRORE`

**Response** (200 OK): Array di annotazioni

**Errori**:
- `400 Bad Request`: Stato non valido

---

### 10. Annotazioni Pubbliche

**Endpoint**: `GET /api/annotazioni/pubbliche`

Recupera solo le annotazioni pubbliche.

**Response** (200 OK): Array di annotazioni

---

### 11. Statistiche

**Endpoint**: `GET /api/annotazioni/statistiche`

Ottiene statistiche generali.

**Response** (200 OK):
```json
{
  "totaleAnnotazioni": 150,
  "dataGenerazione": "2025-11-27T15:30:00"
}
```

---

### 12. Transizioni di Stato

**Endpoint**: `GET /api/annotazioni/transizioni-stato`

Ottiene tutte le transizioni di stato configurate.

**Response** (200 OK):
```json
[
  {
    "id": "uuid",
    "daStato": "INSERITA",
    "aStato": "MODIFICATA",
    "nomeTransizione": "Modifica",
    "descrizione": "Modifica annotazione inserita",
    "richiedeConfermaUtente": false,
    "ruoliAutorizzati": ["USER", "ADMIN"]
  },
  ...
]
```

---

### 13. Cambia Stato

**Endpoint**: `PATCH /api/annotazioni/{id}/stato`

Cambia lo stato di un'annotazione (con validazione transizione).

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Request Body**:
```json
{
  "vecchioStato": "INSERITA",
  "nuovoStato": "MODIFICATA",
  "utente": "mario.rossi"
}
```

**Response** (200 OK):
```json
{
  "id": "uuid",
  "stato": "MODIFICATA",
  ...
}
```

**Errori**:
- `400 Bad Request`: Dati non validi
- `403 Forbidden`: Transizione non permessa
- `404 Not Found`: Annotazione non trovata

---

### 14. Prenota Annotazione

**Endpoint**: `POST /api/annotazioni/{id}/prenota`

Acquisisce un lock temporaneo sull'annotazione per modifica esclusiva.

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Request Body**:
```json
{
  "utente": "mario.rossi",
  "secondi": 60
}
```

**Response** (200 OK):
```json
{
  "annotazioneId": "uuid",
  "utente": "mario.rossi",
  "dataPrenotazione": "2025-11-27T15:30:00",
  "scadenzaPrenotazione": "2025-11-27T15:31:00",
  "prenotata": true,
  "messaggio": "Annotazione prenotata con successo per 60 secondi"
}
```

**Errori**:
- `404 Not Found`: Annotazione non trovata
- `409 Conflict`: Annotazione già bloccata da altro utente

---

### 15. Rilascia Prenotazione

**Endpoint**: `DELETE /api/annotazioni/{id}/prenota`

Rilascia il lock su un'annotazione.

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Request Body**:
```json
{
  "utente": "mario.rossi"
}
```

**Response** (204 No Content): Nessun contenuto

**Errori**:
- `404 Not Found`: Annotazione non trovata
- `409 Conflict`: Lock non posseduto dall'utente

---

### 16. Verifica Stato Prenotazione

**Endpoint**: `GET /api/annotazioni/{id}/prenota/stato`

Verifica se un'annotazione è bloccata.

**Path Parameters**:
- `id` (UUID, obbligatorio): ID dell'annotazione

**Response** (200 OK):
```json
{
  "annotazioneId": "uuid",
  "prenotata": true,
  "utenteProprietario": "mario.rossi"
}
```

---

## 📦 Modelli Dati

### AnnotazioneResponse

```typescript
interface AnnotazioneResponse {
  id: string;                      // UUID
  versioneNota: string;            // Es: "1.0", "1.1"
  valoreNota: string;              // Contenuto della nota
  descrizione: string;             // Descrizione breve
  utenteCreazione: string;         // Username creatore
  dataInserimento: string;         // ISO 8601 DateTime
  dataUltimaModifica: string;      // ISO 8601 DateTime
  utenteUltimaModifica: string;    // Username ultimo modificatore
  categoria: string;               // Categoria (opzionale)
  tags: string;                    // Tags separati da virgola
  pubblica: boolean;               // Visibilità pubblica
  priorita: number;                // 1-5
  stato: string;                   // INSERITA, MODIFICATA, etc.
}
```

---

### Stati Annotazione

```typescript
enum StatoAnnotazione {
  INSERITA = "INSERITA",           // Appena creata
  MODIFICATA = "MODIFICATA",       // Modificata dopo creazione
  CONFERMATA = "CONFERMATA",       // Confermata da revisore
  RIFIUTATA = "RIFIUTATA",         // Rifiutata da revisore
  DAINVIARE = "DAINVIARE",         // In attesa di invio
  INVIATA = "INVIATA",             // Inviata con successo
  SCADUTA = "SCADUTA",             // Scaduta (se ha deadline)
  BANNATA = "BANNATA",             // Bannata da admin
  ERRORE = "ERRORE"                // Errore durante elaborazione
}
```

---

### ErrorResponse

```typescript
interface ErrorResponse {
  message: string;                 // Messaggio errore leggibile
  code: string;                    // Codice errore (es: "ANNOTATION_LOCKED")
}
```

---

## 🔢 Codici di Stato HTTP

| Codice | Significato | Quando viene restituito |
|--------|-------------|-------------------------|
| `200 OK` | Successo | Operazione completata |
| `201 Created` | Risorsa creata | POST con successo |
| `204 No Content` | Successo senza contenuto | DELETE con successo |
| `400 Bad Request` | Dati non validi | Validazione fallita |
| `401 Unauthorized` | Non autenticato | Token mancante o invalido |
| `403 Forbidden` | Non autorizzato | Permessi insufficienti |
| `404 Not Found` | Risorsa non trovata | ID non esistente |
| `409 Conflict` | Conflitto | Lock già acquisito, email duplicata |
| `500 Internal Server Error` | Errore server | Errore interno |

---

## 💡 Esempi Pratici

### Esempio 1: Flusso Completo Login + Crea Annotazione

```javascript
// 1. Login
const loginResponse = await fetch('http://localhost:8080/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    username: 'mario.rossi',
    password: 'password123'
  })
});

const { token } = await loginResponse.json();

// 2. Crea annotazione
const createResponse = await fetch('http://localhost:8080/api/annotazioni', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    valoreNota: 'Contenuto importante',
    descrizione: 'Una nota urgente',
    utente: 'mario.rossi',
    categoria: 'Lavoro',
    tags: 'urgente, importante',
    pubblica: false,
    priorita: 5
  })
});

const annotazione = await createResponse.json();
console.log('Annotazione creata:', annotazione.id);
```

---

### Esempio 2: Prenotazione + Modifica + Rilascio

```javascript
const annotazioneId = 'uuid-annotazione';
const token = 'your-jwt-token';

// 1. Prenota per 60 secondi
const prenotaResponse = await fetch(
  `http://localhost:8080/api/annotazioni/${annotazioneId}/prenota`,
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      utente: 'mario.rossi',
      secondi: 60
    })
  }
);

if (prenotaResponse.ok) {
  // 2. Modifica annotazione (hai 60 secondi)
  const updateResponse = await fetch(
    `http://localhost:8080/api/annotazioni/${annotazioneId}`,
    {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        valoreNota: 'Contenuto aggiornato',
        descrizione: 'Descrizione modificata',
        utente: 'mario.rossi',
        categoria: 'Lavoro',
        priorita: 3
      })
    }
  );

  // 3. Rilascia il lock
  await fetch(
    `http://localhost:8080/api/annotazioni/${annotazioneId}/prenota`,
    {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        utente: 'mario.rossi'
      })
    }
  );
} else {
  const error = await prenotaResponse.json();
  console.error('Annotazione bloccata:', error.message);
}
```

---

### Esempio 3: Cambio Stato con Validazione

```javascript
// Ottieni prima le transizioni valide
const transizioniResponse = await fetch(
  'http://localhost:8080/api/annotazioni/transizioni-stato',
  {
    headers: { 'Authorization': `Bearer ${token}` }
  }
);

const transizioni = await transizioniResponse.json();
console.log('Transizioni disponibili:', transizioni);

// Cambia stato se transizione permessa
const cambiaStatoResponse = await fetch(
  `http://localhost:8080/api/annotazioni/${annotazioneId}/stato`,
  {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      vecchioStato: 'INSERITA',
      nuovoStato: 'CONFERMATA',
      utente: 'admin.user'
    })
  }
);

if (cambiaStatoResponse.status === 403) {
  console.error('Transizione non permessa!');
}
```

---

### Esempio 4: Gestione Errori

```javascript
async function getAnnotazione(id, token) {
  try {
    const response = await fetch(
      `http://localhost:8080/api/annotazioni/${id}`,
      {
        headers: { 'Authorization': `Bearer ${token}` }
      }
    );

    if (!response.ok) {
      switch (response.status) {
        case 401:
          // Token scaduto o invalido
          window.location.href = '/login';
          break;
        case 404:
          console.error('Annotazione non trovata');
          break;
        case 409:
          const error = await response.json();
          console.error('Conflitto:', error.message);
          break;
        case 500:
          console.error('Errore del server');
          break;
        default:
          console.error('Errore sconosciuto:', response.status);
      }
      return null;
    }

    return await response.json();
  } catch (error) {
    console.error('Errore di rete:', error);
    return null;
  }
}
```

---

## 📝 Note Implementative

### Gestione del Token JWT

- Il token ha una validità di **24 ore** (86400 secondi)
- Inviare il token in **ogni richiesta** nell'header `Authorization: Bearer {token}`
- Se il token scade (401), effettuare nuovamente il login o usare refresh token
- Il token contiene: `userId`, `username`, `role`, `accountType`

### Sistema di Lock

- Il lock predefinito dura **42 secondi** (configurabile)
- Puoi specificare la durata nel body della richiesta di prenotazione
- Il lock viene **rilasciato automaticamente** alla scadenza
- Verifica sempre lo stato del lock prima di tentare modifiche

### Transizioni di Stato

- Non tutte le transizioni sono permesse (vedi `/transizioni-stato`)
- Le transizioni sono **configurabili lato server**
- Alcuni stati richiedono ruoli specifici (es: ADMIN per BANNATA)

### Validazioni

Tutti i campi obbligatori vengono validati automaticamente:
- `valoreNota`: 1-10000 caratteri
- `descrizione`: 1-500 caratteri
- `utente`: 1-100 caratteri
- `categoria`: max 100 caratteri
- `tags`: max 500 caratteri

### CORS

Le API supportano richieste da qualsiasi origine (`*`). In produzione, configura le origini permesse.

