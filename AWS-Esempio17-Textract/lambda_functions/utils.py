"""
Modulo condiviso dalle lambda dell'esempio 17.
Viene inserito in tutti gli archivi ZIP (vedi lambda.tf).
"""
import json
import os
import re
from decimal import Decimal

# Le immagini passano dalle operazioni SINCRONE di Textract (una sola pagina,
# risposta immediata); i PDF passano dalle operazioni ASINCRONE Start*/Get*,
# le uniche che accettano documenti multipagina.
ESTENSIONI_IMMAGINE = ('.jpg', '.jpeg', '.png')
ESTENSIONI_PDF = ('.pdf',)
ALLOWED_EXTENSIONS = ESTENSIONI_IMMAGINE + ESTENSIONI_PDF

# Feature ammesse da AnalyzeDocument.
FEATURE_TYPES_VALIDI = ('TABLES', 'FORMS', 'SIGNATURES', 'LAYOUT', 'QUERIES')

# Limiti imposti da Textract sulle query (operazioni sincrone).
MAX_QUERY_TEXT = 200
MAX_QUERY_ALIAS = 200

# Un alias di query puo' contenere solo questi caratteri.
ALIAS_VALIDO = re.compile(r'^[a-zA-Z0-9_\- ]+$')

# Textract accetta SOLO caratteri ASCII nel testo delle query: una domanda
# scritta con le lettere accentate ("Qual e' il totale?" va bene, "Qual è
# l'importo?" no) viene rifiutata con una ValidationException poco leggibile.
# Meglio intercettarla qui e dirlo in chiaro.
QUERY_TESTO_VALIDO = re.compile(
    r'^[a-zA-Z0-9\s!"#$%\'&()*+,\-./:;=?@\[\\\]^_`{|}~><]+$'
)

# Indicazione delle pagine su cui vale una query (solo per i PDF):
# "1", "*", "1-3", "2-*" ... massimo 9 caratteri.
PAGINE_VALIDE = re.compile(r'^[0-9*\-]+$')


def decimal_default(obj):
    """Serializzatore JSON per i Decimal (e per i float che arrivano da boto3)."""
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    raise TypeError(f"Tipo non serializzabile: {type(obj)}")


def api_response(status_code: int, body: dict) -> dict:
    """
    Risposta standard per l'integrazione proxy di API Gateway.

    Gli header CORS sono necessari anche qui: i metodi OPTIONS definiti in
    api_gateway_cors.tf coprono solo il preflight, non le risposte reali.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body, default=decimal_default, ensure_ascii=False)
    }


def e_pdf(nome: str) -> bool:
    """True se il file va trattato come PDF (analisi asincrona)."""
    return nome.lower().endswith(ESTENSIONI_PDF)


def estensione_minuscola(filename: str) -> str:
    """
    Restituisce il nome file con la sola estensione in minuscolo.

    Serve per la key S3: le notifiche S3 filtrano per suffisso in modo
    case-sensitive, quindi un file caricato come "Foto.PNG" non farebbe
    scattare nessun trigger.
    """
    radice, punto, estensione = filename.rpartition('.')
    return f"{radice}{punto}{estensione.lower()}" if punto else filename


def validate_filename(filename: str) -> str:
    """
    Valida il nome del file richiesto dal browser.

    Rifiuta path assoluti, path traversal, null byte e estensioni non
    supportate da Textract.

    Returns:
        Il nome file ripulito (senza eventuali directory), con la stessa
        combinazione di maiuscole e minuscole scelta dall'utente.

    Raises:
        ValueError: se il nome non e' utilizzabile come key S3.
    """
    if not filename or not filename.strip():
        raise ValueError("Il nome del file non puo' essere vuoto")

    filename = filename.strip()

    if '\x00' in filename:
        raise ValueError("Il nome del file contiene caratteri non validi")

    # Si tiene solo l'ultima parte del path: niente cartelle scelte dal client
    filename = os.path.basename(filename.replace('\\', '/'))

    if not filename or filename in ('.', '..'):
        raise ValueError("Il nome del file non e' valido")

    if len(filename.encode('utf-8')) > 512:
        raise ValueError("Nome del file troppo lungo (max 512 byte)")

    if not filename.lower().endswith(ALLOWED_EXTENSIONS):
        raise ValueError(
            "Estensione non supportata: questo esempio accetta solo file "
            f"{', '.join(ALLOWED_EXTENSIONS)}"
        )

    return filename


def normalizza_opzioni(grezze: dict, default: dict, max_queries: int) -> dict:
    """
    Valida e normalizza le opzioni Textract arrivate dalla pagina web.

    Args:
        grezze: dizionario cosi' come arriva dal browser (puo' essere vuoto).
        default: valori da usare per i campi non specificati.
        max_queries: numero massimo di query accettate.

    Returns:
        Dizionario con le chiavi feature_types, queries, min_confidence,
        salva_blocchi_grezzi, nota.

    Raises:
        ValueError: se una opzione non e' utilizzabile.
    """
    grezze = grezze or {}

    # ---- feature types ----
    feature_types = grezze.get('feature_types')
    if feature_types is None:
        feature_types = list(default.get('feature_types', []))
    if not isinstance(feature_types, list):
        raise ValueError("Il campo 'feature_types' deve essere una lista")

    normalizzate = []
    for feature in feature_types:
        valore = str(feature).strip().upper()
        if valore not in FEATURE_TYPES_VALIDI:
            raise ValueError(
                f"Feature '{feature}' non valida: valori ammessi "
                f"{', '.join(FEATURE_TYPES_VALIDI)}"
            )
        if valore not in normalizzate:
            normalizzate.append(valore)

    # ---- queries ----
    queries_grezze = grezze.get('queries')
    if queries_grezze is None:
        queries_grezze = list(default.get('queries', []))
    if not isinstance(queries_grezze, list):
        raise ValueError("Il campo 'queries' deve essere una lista")

    queries = []
    alias_usati = set()
    for indice, query in enumerate(queries_grezze, start=1):
        # Si accetta sia { "text": ..., "alias": ... } sia la sola stringa
        if isinstance(query, str):
            query = {'text': query}
        if not isinstance(query, dict):
            raise ValueError("Ogni query deve essere una stringa o un oggetto con 'text'")

        testo = str(query.get('text') or '').strip()
        if not testo:
            continue
        if len(testo) > MAX_QUERY_TEXT:
            raise ValueError(f"La query {indice} supera i {MAX_QUERY_TEXT} caratteri ammessi")
        if not QUERY_TESTO_VALIDO.match(testo):
            fuori = sorted({c for c in testo if not QUERY_TESTO_VALIDO.match(c)})
            raise ValueError(
                f"La query {indice} contiene caratteri che Textract non accetta "
                f"({' '.join(fuori)}): usare solo caratteri ASCII, per esempio "
                "\"Qual e' il totale?\" invece di \"Qual \u00e8 il totale?\""
            )

        alias = str(query.get('alias') or '').strip()
        if not alias:
            alias = f"q{indice}"
        if len(alias) > MAX_QUERY_ALIAS:
            raise ValueError(f"L'alias della query {indice} supera i {MAX_QUERY_ALIAS} caratteri")
        if not ALIAS_VALIDO.match(alias):
            raise ValueError(
                f"L'alias '{alias}' contiene caratteri non ammessi "
                "(sono consentiti lettere, numeri, spazio, '-' e '_')"
            )
        if alias in alias_usati:
            raise ValueError(f"L'alias '{alias}' e' usato piu' di una volta")
        alias_usati.add(alias)

        normalizzata = {'text': testo, 'alias': alias}

        # 'pages' limita la query ad alcune pagine ed ha senso solo sui PDF:
        # "1", "*", "1-3", "2-*". Sulle immagini Textract la rifiuta.
        pagine_grezze = query.get('pages')
        if pagine_grezze:
            if isinstance(pagine_grezze, str):
                pagine_grezze = [p.strip() for p in pagine_grezze.split(',')]
            if not isinstance(pagine_grezze, list):
                raise ValueError(f"Il campo 'pages' della query {indice} deve essere una lista")
            pagine = []
            for pagina in pagine_grezze:
                pagina = str(pagina).strip()
                if not pagina:
                    continue
                if len(pagina) > 9 or not PAGINE_VALIDE.match(pagina):
                    raise ValueError(
                        f"Indicazione di pagina non valida nella query {indice}: '{pagina}'. "
                        "Sono ammessi valori come 1, 1-3, 2-* oppure *"
                    )
                pagine.append(pagina)
            if pagine:
                normalizzata['pages'] = pagine

        queries.append(normalizzata)

    if len(queries) > max_queries:
        raise ValueError(
            f"Sono state indicate {len(queries)} query: il massimo ammesso e' {max_queries}"
        )

    # QUERIES senza query e' un errore lato Textract: meglio intercettarlo qui
    if 'QUERIES' in normalizzate and not queries:
        raise ValueError("La feature QUERIES richiede almeno una query")
    # Viceversa, se ci sono query la feature va aggiunta in automatico
    if queries and 'QUERIES' not in normalizzate:
        normalizzate.append('QUERIES')

    # ---- confidenza minima ----
    if 'min_confidence' in grezze and grezze.get('min_confidence') is not None:
        try:
            min_confidence = float(grezze['min_confidence'])
        except (TypeError, ValueError):
            raise ValueError("Il campo 'min_confidence' deve essere un numero")
    else:
        min_confidence = float(default.get('min_confidence', 80))

    if not 0 <= min_confidence <= 100:
        raise ValueError("Il campo 'min_confidence' deve essere compreso fra 0 e 100")

    # ---- blocchi grezzi ----
    if 'salva_blocchi_grezzi' in grezze and grezze.get('salva_blocchi_grezzi') is not None:
        salva_grezzi = str(grezze['salva_blocchi_grezzi']).lower() in ('true', '1', 'si', 'yes', 'on')
    else:
        salva_grezzi = bool(default.get('salva_blocchi_grezzi', False))

    # ---- nota libera ----
    nota = str(grezze.get('nota') or '').strip()[:500]

    return {
        'feature_types': normalizzate,
        'queries': queries,
        'min_confidence': round(min_confidence, 2),
        'salva_blocchi_grezzi': salva_grezzi,
        'nota': nota,
    }
