import requests

def get_lyrics():
    base_url = "https://lrclib.net/api/get"
    # params = {"track_name": "Machine Love", "artist_name": "Jamie Paige", "album_name": "DAEMON/DOLL", "duration": 216}
    params = {"track_name": "Elephant", "artist_name": "Boa", "album_name": "Twilight", "duration": 234}
    
    try:
        response = requests.get(base_url, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}

if __name__ == "__main__":
    print("lrclib.net")
    print("--------------------------------------")
    
    result = get_lyrics()
    
    print(result)
    print("--------")
    
    print("\n" + "="*50 + "\n")
