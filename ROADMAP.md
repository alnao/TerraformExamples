# AlNao terraform roadmap

*Perchè non iniziare un nuovo progetto quando ce ne sono 100 in go?*

Qui elencati alcuni appunti liberi di cose che vorrei fare

    - riconoscimento targhe "OCR / targhe / cartelli" con Textract
        - Per una targa in una foto di un parcheggio, o per un cartello stradale, DetectText di Rekognition è più adatto.
- FaceBlur
    - data un gruppo di immagini dei volti di persone "safe" e "persone non safe", mi crei un progetto che 
        - Ricerca volti	CreateCollection + IndexFaces + SearchFacesByImage	Mostra il concetto di collection e la ricerca 1:N, diverso da tutto il resto
        - bucket dove si caricano immagini, path parametrizzabile "input/" -> per ogni volto presente se nel gruppo dei safe scrive su tabella dynamo "safe" e sposta in paths parametro "safe/", per ogni volto non safe, fa blur del volto e sposta immagine su "unsafe" mettendo su paths parametro "unsafe/". 

    
        - Valore didattico doppio: nel repository non hai ancora un esempio di Lambda con dipendenze native (Pillow richiede un layer o una container image) — quello è il vero contenuto dell'esempio, Rekognition è il pretesto. Complementare a "ricerca volti" che hai in roadmap: lì identifichi le persone, qui le nascondi.
        
        - evoluzione DPI sul lavoro	DetectProtectiveEquipment: Caschi, gilet, guanti su foto di cantiere → alert. Molto concreto
            se nell'immagine dei safe NON c'è un casco o una bandana o cappellino sposta immagine in dangerous e manda notifica SNS dicendo che quella immagine, in dynamo su tabella safe aggiungere flag "dangerous"
        - evoluzione da video estrarre immagini con persone (ogni tot secondi?) e poi fai il giro di sopra, ce la fai?
            
- Video: indice navigabile
StartLabelDetection → SNS → GetLabelDetection, orchestrato con Step Functions (Esempio07). Ottieni le label con i timestamp: la pagina web diventa un player con una timeline cliccabile ("vai al minuto in cui compare l'auto"). È l'unico della lista che ti insegna il pattern job asincrono con notifica, che nel repository manca.
- Rekognition vs Bedrock, stessa immagine: Un esempio "duello": la stessa foto passa a DetectLabels e a un modello multimodale su Bedrock, e la pagina mostra le due risposte affiancate con tempi e costi. Originale, onesto, e risponde alla domanda che oggi si fanno tutti — quando conviene ancora l'API specializzata?. Nel repository Bedrock non c'è ancora.

- evoluzione Esempio16 con anche "moderazione", se rientra spostare immagine e tabella, usare SNS