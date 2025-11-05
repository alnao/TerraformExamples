from pymongo import MongoClient

# Sostituisci con la tua connection string (puoi recuperarla da Key Vault)
connection_string = "mongodb://<username>:<password>@<cluster>.mongo.cosmos.azure.com:10255/?ssl=true&retrywrites=false"

# Connessione al cluster

client = MongoClient(connection_string)
db = client['mydatabase']
collection = db['annotazioni']

# Test inserimento
print ("Inserimento di una annotazione di prova...")
collection.insert_one({"test": "annotazione di prova"})

print ( "Collezione 'annotazioni':")
print(collection.find_one())