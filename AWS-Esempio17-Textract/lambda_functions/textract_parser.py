"""
Parser della risposta di Amazon Textract.

Textract non restituisce un documento strutturato ma una lista piatta di
"blocchi" (Blocks) collegati fra loro da relazioni:

    PAGE ──CHILD──> LINE ──CHILD──> WORD
    TABLE ──CHILD──> CELL ──CHILD──> WORD
    KEY_VALUE_SET(KEY) ──VALUE──> KEY_VALUE_SET(VALUE) ──CHILD──> WORD
    QUERY ──ANSWER──> QUERY_RESULT

Questo modulo naviga quelle relazioni e produce un dizionario leggibile,
che e' esattamente quello che viene salvato nel JSON su S3.
"""


def _indice_blocchi(blocks):
    """Dizionario Id -> blocco, per seguire le relazioni senza scansioni ripetute."""
    return {blocco['Id']: blocco for blocco in blocks if 'Id' in blocco}


def _figli(blocco, per_id, tipi=None):
    """Blocchi collegati da una relazione CHILD, eventualmente filtrati per BlockType."""
    risultato = []
    for relazione in blocco.get('Relationships') or []:
        if relazione.get('Type') != 'CHILD':
            continue
        for id_figlio in relazione.get('Ids') or []:
            figlio = per_id.get(id_figlio)
            if figlio and (tipi is None or figlio.get('BlockType') in tipi):
                risultato.append(figlio)
    return risultato


def _testo(blocco, per_id):
    """
    Testo di un blocco composto: concatena le WORD figlie.

    I checkbox (SELECTION_ELEMENT) non hanno testo, vengono rappresentati
    con [X] se selezionati e [ ] altrimenti.
    """
    if blocco.get('BlockType') == 'WORD':
        return blocco.get('Text', '')

    pezzi = []
    for figlio in _figli(blocco, per_id, ('WORD', 'SELECTION_ELEMENT')):
        if figlio['BlockType'] == 'WORD':
            testo = figlio.get('Text', '')
            if testo:
                pezzi.append(testo)
        else:
            pezzi.append('[X]' if figlio.get('SelectionStatus') == 'SELECTED' else '[ ]')
    return ' '.join(pezzi)


def _confidenza(blocco):
    return round(float(blocco.get('Confidence', 0.0)), 2)


def _riquadro(blocco):
    """BoundingBox normalizzato (valori 0-1) arrotondato, utile per evidenziare il testo."""
    box = (blocco.get('Geometry') or {}).get('BoundingBox') or {}
    if not box:
        return None
    return {
        'left': round(float(box.get('Left', 0)), 4),
        'top': round(float(box.get('Top', 0)), 4),
        'width': round(float(box.get('Width', 0)), 4),
        'height': round(float(box.get('Height', 0)), 4),
    }


# ====================================
# TESTO
# ====================================

def estrai_righe(blocks, per_id, min_confidence):
    """
    Righe di testo (blocchi LINE) con confidenza >= min_confidence.

    Nota: Textract, a differenza di Rekognition, non ha un parametro
    MinConfidence nella richiesta. Il filtro si applica qui, sui risultati.
    """
    righe = []
    scartate = 0

    for blocco in blocks:
        if blocco.get('BlockType') != 'LINE':
            continue
        confidenza = _confidenza(blocco)
        if confidenza < min_confidence:
            scartate += 1
            continue
        righe.append({
            'text': blocco.get('Text', ''),
            'confidence': confidenza,
            'page': blocco.get('Page', 1),
            'box': _riquadro(blocco),
        })

    return righe, scartate


# ====================================
# TABELLE (feature TABLES)
# ====================================

def estrai_tabelle(blocks, per_id):
    """
    Ricostruisce le tabelle come matrici di stringhe.

    Ogni CELL porta RowIndex/ColumnIndex (base 1) e, quando la cella e'
    unita, RowSpan/ColumnSpan: il valore viene replicato su tutte le celle
    coperte cosi' la matrice resta rettangolare e facile da stampare.
    """
    tabelle = []

    for blocco in blocks:
        if blocco.get('BlockType') != 'TABLE':
            continue

        celle = []
        titolo = ''
        note = []
        for figlio in _figli(blocco, per_id):
            tipo = figlio.get('BlockType')
            if tipo == 'CELL':
                celle.append(figlio)
            elif tipo == 'TABLE_TITLE':
                titolo = _testo(figlio, per_id)
            elif tipo == 'TABLE_FOOTER':
                note.append(_testo(figlio, per_id))

        if not celle:
            continue

        n_righe = max(c.get('RowIndex', 1) + c.get('RowSpan', 1) - 1 for c in celle)
        n_colonne = max(c.get('ColumnIndex', 1) + c.get('ColumnSpan', 1) - 1 for c in celle)
        griglia = [['' for _ in range(n_colonne)] for _ in range(n_righe)]
        intestazione = [False] * n_righe

        for cella in celle:
            testo = _testo(cella, per_id)
            riga0 = cella.get('RowIndex', 1) - 1
            col0 = cella.get('ColumnIndex', 1) - 1
            for riga in range(riga0, riga0 + cella.get('RowSpan', 1)):
                for colonna in range(col0, col0 + cella.get('ColumnSpan', 1)):
                    if 0 <= riga < n_righe and 0 <= colonna < n_colonne:
                        griglia[riga][colonna] = testo
            if 'COLUMN_HEADER' in (cella.get('EntityTypes') or []) and 0 <= riga0 < n_righe:
                intestazione[riga0] = True

        tabelle.append({
            'page': blocco.get('Page', 1),
            'title': titolo,
            'footers': note,
            'n_rows': n_righe,
            'n_columns': n_colonne,
            'header_rows': [i for i, e in enumerate(intestazione) if e],
            'confidence': _confidenza(blocco),
            'rows': griglia,
        })

    return tabelle


# ====================================
# CAMPI DI UN MODULO (feature FORMS)
# ====================================

def estrai_campi(blocks, per_id):
    """
    Coppie chiave/valore dei moduli.

    Il blocco KEY (KEY_VALUE_SET con EntityTypes contenente 'KEY') punta al
    proprio VALUE con una relazione di tipo VALUE; il testo di entrambi si
    ottiene seguendo le CHILD fino alle WORD.
    """
    campi = []

    for blocco in blocks:
        if blocco.get('BlockType') != 'KEY_VALUE_SET':
            continue
        if 'KEY' not in (blocco.get('EntityTypes') or []):
            continue

        chiave = _testo(blocco, per_id)

        valore = ''
        confidenza_valore = 0.0
        selezionato = None
        for relazione in blocco.get('Relationships') or []:
            if relazione.get('Type') != 'VALUE':
                continue
            for id_valore in relazione.get('Ids') or []:
                blocco_valore = per_id.get(id_valore)
                if not blocco_valore:
                    continue
                valore = _testo(blocco_valore, per_id)
                confidenza_valore = _confidenza(blocco_valore)
                # Se il valore e' un checkbox si espone anche lo stato "puro"
                for figlio in _figli(blocco_valore, per_id, ('SELECTION_ELEMENT',)):
                    selezionato = figlio.get('SelectionStatus') == 'SELECTED'

        campi.append({
            'page': blocco.get('Page', 1),
            'key': chiave,
            'value': valore,
            'key_confidence': _confidenza(blocco),
            'value_confidence': confidenza_valore,
            'selected': selezionato,
        })

    return campi


# ====================================
# QUERIES (feature QUERIES)
# ====================================

def estrai_risposte_query(blocks, per_id):
    """
    Risposte alle domande poste con la feature QUERIES.

    Ogni blocco QUERY contiene la domanda e punta, con una relazione ANSWER,
    ai blocchi QUERY_RESULT che contengono la risposta trovata nel documento.
    Quando Textract non trova nulla la relazione ANSWER e' assente: in quel
    caso si restituisce comunque la domanda con risposta vuota.
    """
    risposte = []

    for blocco in blocks:
        if blocco.get('BlockType') != 'QUERY':
            continue

        query = blocco.get('Query') or {}
        trovate = []
        for relazione in blocco.get('Relationships') or []:
            if relazione.get('Type') != 'ANSWER':
                continue
            for id_risposta in relazione.get('Ids') or []:
                risultato = per_id.get(id_risposta)
                if not risultato:
                    continue
                testo = (risultato.get('Text') or '').strip()
                if testo:
                    trovate.append({'text': testo, 'confidence': _confidenza(risultato)})

        # La risposta migliore e' quella con la confidenza piu' alta
        trovate.sort(key=lambda r: r['confidence'], reverse=True)

        risposte.append({
            'page': blocco.get('Page', 1),
            'question': query.get('Text', ''),
            'alias': query.get('Alias', ''),
            'answer': trovate[0]['text'] if trovate else '',
            'confidence': trovate[0]['confidence'] if trovate else 0.0,
            'found': bool(trovate),
            'other_answers': [r['text'] for r in trovate[1:]],
        })

    return risposte


# ====================================
# FIRME (feature SIGNATURES) E LAYOUT (feature LAYOUT)
# ====================================

def estrai_firme(blocks):
    """Posizione e confidenza delle firme rilevate nel documento."""
    return [
        {'page': b.get('Page', 1), 'confidence': _confidenza(b), 'box': _riquadro(b)}
        for b in blocks if b.get('BlockType') == 'SIGNATURE'
    ]


def estrai_layout(blocks, per_id):
    """
    Elementi di impaginazione (titoli, paragrafi, elenchi, note...).

    I blocchi di layout hanno BlockType che inizia con 'LAYOUT_' e puntano
    con relazioni CHILD alle LINE che li compongono.
    """
    elementi = []

    for blocco in blocks:
        tipo = blocco.get('BlockType', '')
        if not tipo.startswith('LAYOUT_'):
            continue

        pezzi = []
        for figlio in _figli(blocco, per_id, ('LINE', 'WORD')):
            testo = figlio.get('Text') or _testo(figlio, per_id)
            if testo:
                pezzi.append(testo)

        elementi.append({
            'page': blocco.get('Page', 1),
            'type': tipo.replace('LAYOUT_', ''),
            'text': ' '.join(pezzi),
            'confidence': _confidenza(blocco),
        })

    return elementi


# ====================================
# FUNZIONE PRINCIPALE
# ====================================

def _testo_completo(righe):
    """
    Testo del documento, con le pagine separate da una riga vuota.

    Su una immagine (una pagina sola) il risultato e' identico al semplice
    join delle righe; su un PDF il separatore rende leggibile dove finisce
    una pagina e comincia la successiva.
    """
    pezzi = []
    pagina_corrente = None

    for riga in righe:
        if pagina_corrente is not None and riga['page'] != pagina_corrente:
            pezzi.append('')
        pezzi.append(riga['text'])
        pagina_corrente = riga['page']

    return '\n'.join(pezzi)


def elabora_risposta(risposta_textract, min_confidence):
    """
    Trasforma la risposta di Textract nella struttura salvata su S3.

    Funziona senza modifiche sia sulla risposta sincrona (detect_document_text
    o analyze_document) sia su quella ricomposta dalle chiamate asincrone
    Get* sui PDF: cambia solo il numero di blocchi e di pagine.

    Args:
        risposta_textract: dizionario con la chiave 'Blocks' e, quando
            disponibile, 'DocumentMetadata'.
        min_confidence: soglia di confidenza per le righe di testo.

    Returns:
        Dizionario con testo, righe, tabelle, campi, risposte alle query,
        firme, layout e qualche statistica di riepilogo.
    """
    blocks = risposta_textract.get('Blocks') or []
    metadata = risposta_textract.get('DocumentMetadata') or {}
    per_id = _indice_blocchi(blocks)

    righe, righe_scartate = estrai_righe(blocks, per_id, min_confidence)
    testo = _testo_completo(righe)

    tipi_presenti = {b.get('BlockType') for b in blocks}
    n_parole = sum(1 for b in blocks if b.get('BlockType') == 'WORD')
    confidenze = [riga['confidence'] for riga in righe]

    risultato = {
        'text': testo,
        'lines': righe,
        'tables': estrai_tabelle(blocks, per_id) if 'TABLE' in tipi_presenti else [],
        'forms': estrai_campi(blocks, per_id) if 'KEY_VALUE_SET' in tipi_presenti else [],
        'queries': estrai_risposte_query(blocks, per_id) if 'QUERY' in tipi_presenti else [],
        'signatures': estrai_firme(blocks) if 'SIGNATURE' in tipi_presenti else [],
        'layout': estrai_layout(blocks, per_id) if any(t.startswith('LAYOUT_') for t in tipi_presenti if t) else [],
    }

    # Sui PDF il numero di pagine arriva da DocumentMetadata; sulle immagini
    # quel campo puo' mancare e si contano i blocchi PAGE.
    n_pagine = metadata.get('Pages') or \
        len({b.get('Page', 1) for b in blocks if b.get('BlockType') == 'PAGE'}) or 1

    risultato['stats'] = {
        'n_pages': n_pagine,
        'n_blocks': len(blocks),
        'n_lines': len(righe),
        'n_lines_discarded': righe_scartate,
        'n_words': n_parole,
        'n_characters': len(testo),
        'n_tables': len(risultato['tables']),
        'n_forms': len(risultato['forms']),
        'n_queries': len(risultato['queries']),
        'n_queries_answered': sum(1 for q in risultato['queries'] if q['found']),
        'n_signatures': len(risultato['signatures']),
        'avg_confidence': round(sum(confidenze) / len(confidenze), 2) if confidenze else 0.0,
        'min_confidence_found': min(confidenze) if confidenze else 0.0,
    }

    return risultato
