import json
from musicxmatch_api import MusixMatchAPI
api = MusixMatchAPI()
search = api.search_tracks("Yurie Kokubu")
print(json.dumps(search, indent=4))