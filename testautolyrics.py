import requests
from urllib.parse import quote

def get_lyrics(title, artist, token):
    base_url = "https://apic-desktop.musixmatch.com/ws/1.1/macro.subtitles.get"
    
    params = {
        "app_id": "web-desktop-app-v1.0",
        "usertoken": token,
        "q_track": title,
        "q_artist": artist,
    }
    
    headers = {
        "Cookie": f"x-mxm-token-guid={token}"
    }
    
    try:
        response = requests.get(base_url, params=params, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}

if __name__ == "__main__":
    TOKEN = "2501192ac605cc2e16b6b2c04fe43d1011a38d919fe802976084e7"
    
    print("Musixmatch Lyrics Finder")
    print("-----------------------")
    
    while True:
        artist = input("Enter artist name: ").strip()            
        title = input("Enter song title: ").strip()
        
        result = get_lyrics(title, artist, TOKEN)
        
        print("\nResults:")
        print("--------")
        print(f"Artist: {artist}")
        print(f"Title: {title}")
        
        # Check if lyrics were found
        if result.get('message', {}).get('body', {}).get('macro_calls', {}).get('track.lyrics.get', {}).get('message', {}).get('header', {}).get('status_code') == 200:
            lyrics = result['message']['body']['macro_calls']['track.lyrics.get']['message']['body']['lyrics']['lyrics_body']
            print("\nLyrics:\n")
            print(lyrics)
        else:
            print("\nNo lyrics found for this track.")
        
        print("\n" + "="*50 + "\n")