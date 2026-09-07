<!doctype html>
<html lang="it">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Esempio 18 - Storico allarmi</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<div class="container py-4">

  <h1 class="h3 mb-1">Storico degli allarmi</h1>
  <p class="text-muted">
    Le righe arrivano da DynamoDB: allarme CloudWatch &rarr; SNS &rarr; Lambda &rarr; DynamoDB &rarr; API Gateway.
  </p>

  <div class="row g-2 align-items-end mb-3">
    <div class="col-sm-5">
      <label class="form-label" for="filtro">Filtra per nome allarme (vuoto = tutti)</label>
      <input id="filtro" class="form-control" placeholder="nome esatto dell'allarme">
    </div>
    <div class="col-sm-3">
      <label class="form-label" for="limite">Righe</label>
      <input id="limite" class="form-control" type="number" value="50" min="1" max="200">
    </div>
    <div class="col-sm-4 d-flex gap-2">
      <button id="aggiorna" class="btn btn-primary">Aggiorna</button>
      <a class="btn btn-outline-secondary" href="/ko">genera un errore</a>
    </div>
  </div>

  <div id="stato" class="alert alert-secondary">Caricamento in corso...</div>

  <div class="table-responsive">
    <table class="table table-sm table-striped align-middle bg-white">
      <thead>
        <tr>
          <th>Istante</th><th>Allarme</th><th>Stato</th><th>Metrica</th><th>Motivo</th>
        </tr>
      </thead>
      <tbody id="righe"></tbody>
    </table>
  </div>

  <p class="text-muted small">
    API: <code>${api_url}/allarmi</code> &mdash;
    la mail SNS arriva comunque, questa pagina e' solo lo storico consultabile.
  </p>
</div>

<script>
  const API_URL = "${api_url}";

  const COLORI = { ALARM: "danger", OK: "success", INSUFFICIENT_DATA: "warning" };

  async function carica() {
    const stato = document.getElementById("stato");
    const righe = document.getElementById("righe");
    const filtro = document.getElementById("filtro").value.trim();
    const limite = document.getElementById("limite").value || 50;

    stato.className = "alert alert-secondary";
    stato.textContent = "Caricamento in corso...";
    righe.innerHTML = "";

    let url = API_URL + "/allarmi?limit=" + encodeURIComponent(limite);
    if (filtro) { url += "&alarm_name=" + encodeURIComponent(filtro); }

    try {
      const risposta = await fetch(url);
      if (!risposta.ok) { throw new Error("HTTP " + risposta.status); }
      const dati = await risposta.json();
      const allarmi = dati.allarmi || [];

      if (allarmi.length === 0) {
        stato.className = "alert alert-info";
        stato.textContent = "Nessun evento registrato: prova a chiamare /ko e aspetta qualche minuto.";
        return;
      }

      stato.className = "alert alert-success";
      stato.textContent = allarmi.length + " eventi trovati (su " + dati.totale + " in tabella).";

      for (const a of allarmi) {
        const tr = document.createElement("tr");
        tr.innerHTML =
          "<td class='text-nowrap'>" + testo(a.timestamp) + "</td>" +
          "<td>" + testo(a.alarm_name) + "</td>" +
          "<td><span class='badge text-bg-" + (COLORI[a.stato] || "secondary") + "'>" + testo(a.stato) + "</span></td>" +
          "<td>" + testo(a.metrica) + "</td>" +
          "<td class='small'>" + testo(a.motivo || a.descrizione) + "</td>";
        righe.appendChild(tr);
      }
    } catch (errore) {
      stato.className = "alert alert-danger";
      stato.textContent = "Errore nella chiamata all'API: " + errore.message;
    }
  }

  function testo(valore) {
    return String(valore === undefined || valore === null ? "" : valore)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  document.getElementById("aggiorna").addEventListener("click", carica);
  carica();
  setInterval(carica, 30000);
</script>
</body>
</html>
