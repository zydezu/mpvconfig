import requests

def get_lyrics(song_title):
    base_url = "https://api.some-random-api.com/lyrics"
    params = {"title": song_title}
    
    try:
        response = requests.get(base_url, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}

if __name__ == "__main__":
    print("Simple Lyrics Finder (some-random-api)")
    print("--------------------------------------")
    
    while True:
        title = input("Enter song title: ").strip()
        
        result = get_lyrics(title)
        
        print("\nResults:")
        print("--------")
        print(f"Title: {title}")
        
        if "lyrics" in result:
            print(f"\nAuthor: {result.get('author', 'Unknown')}")
            print("\nLyrics:\n")
            print(result["lyrics"])
        elif "error" in result:
            print(f"\nError: {result['error']}")
        else:
            print("\nNo lyrics found.")
        
        print("\n" + "="*50 + "\n")
