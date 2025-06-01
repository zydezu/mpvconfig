import requests
import json

def get_sponsor_segments(video_id, categories=None):
    url = "https://sponsor.ajay.app/api/skipSegments"

    # Build query parameters
    params = {
        "videoID": video_id
    }

    # Optional query params
    if categories:
        for category in categories:
            params.setdefault("category", []).append(category)
    
    # Send request
    response = requests.get(url, params=params)

    # Check for success
    if response.status_code == 200:
        segments = response.json()
        print(f"Segments for video ID '{video_id}':\n")
        print(json.dumps(segments, indent=2))
    else:
        print(f"Request failed with status code {response.status_code}: {response.text}")

# Example usage
video_id = "yQHFCpO6gHE"
categories = [
    "sponsor",
    "intro",
    "outro",
    "interaction",
    "selfpromo",
    "preview",
    "music_offtopic",
    "filler",
    "poi_highlight"
]

get_sponsor_segments(video_id, categories)
input()