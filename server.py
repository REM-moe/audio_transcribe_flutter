from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os
import tempfile
import subprocess

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

WHISPER_URL = "http://127.0.0.1:8100/inference"
OLLAMA_URL = "http://localhost:11434/api/generate"

def convert_audio_to_wav(input_file, output_path):
    """Convert any audio file to WAV format for Whisper with better quality"""
    try:
        # Better FFmpeg settings to avoid quality issues
        cmd = [
            'ffmpeg', '-i', input_file, 
            '-ar', '16000',  # 16kHz sample rate
            '-ac', '1',      # Mono
            '-c:a', 'pcm_s16le',  # 16-bit PCM
            '-af', 'highpass=f=80,lowpass=f=8000',  # Audio filtering to remove noise
            '-y', output_path
        ]
        
        print(f"🔧 Converting audio: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ FFmpeg error: {result.stderr}")
            raise Exception(f"FFmpeg conversion failed: {result.stderr}")
        
        # Check if output file was created and has content
        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            raise Exception("Converted file is empty or doesn't exist")
            
        file_size = os.path.getsize(output_path)
        print(f"✅ Converted to WAV: {file_size} bytes")
        return True
        
    except FileNotFoundError:
        raise Exception("FFmpeg not found. Install it with: apt install ffmpeg")
    except Exception as e:
        raise Exception(f"Audio conversion failed: {str(e)}")

@app.route('/transcribe', methods=['POST'])
def transcribe():
    """Transcription with auto audio conversion and debugging"""
    try:
        audio_file = None
        tmp_input_path = None
        
        # Handle both multipart and JSON requests
        if request.content_type and 'multipart/form-data' in request.content_type:
            # Original multipart handling
            if 'file' not in request.files:
                return jsonify({"error": "No file provided"}), 400
            
            audio_file = request.files['file']
            print(f"📁 Received multipart file: {audio_file.filename}")
            
            # Save uploaded file temporarily
            with tempfile.NamedTemporaryFile(delete=False, suffix='.tmp') as tmp_input:
                audio_file.save(tmp_input.name)
                tmp_input_path = tmp_input.name
                input_size = os.path.getsize(tmp_input_path)
                print(f"📁 Saved input file: {input_size} bytes")
                
        elif request.content_type and 'application/json' in request.content_type:
            # New JSON with base64 handling
            data = request.get_json()
            if not data or 'audio_data' not in data:
                return jsonify({"error": "No audio_data provided in JSON"}), 400
            
            print(f"📁 Received JSON with base64 audio data")
            print(f"📁 Base64 length: {len(data['audio_data'])} characters")
            
            # Decode base64 audio data
            try:
                import base64
                audio_bytes = base64.b64decode(data['audio_data'])
                print(f"📁 Decoded audio: {len(audio_bytes)} bytes")
            except Exception as e:
                return jsonify({"error": f"Invalid base64 audio data: {str(e)}"}), 400
            
            # Save decoded audio to temp file
            with tempfile.NamedTemporaryFile(delete=False, suffix='.aac') as tmp_input:
                tmp_input.write(audio_bytes)
                tmp_input_path = tmp_input.name
                print(f"📁 Saved decoded audio: {len(audio_bytes)} bytes")
        else:
            return jsonify({"error": "Invalid content type. Use multipart/form-data or application/json"}), 400
        
        try:
            # Convert to WAV
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as tmp_wav:
                tmp_wav_path = tmp_wav.name
            
            convert_audio_to_wav(tmp_input_path, tmp_wav_path)
            
            # Send WAV to Whisper with better parameters
            with open(tmp_wav_path, 'rb') as wav_file:
                files = {'file': wav_file}
                data = {
                    'response_format': 'json',  # Simple JSON without segments
                    'language': '',  # Let it auto-detect
                    'task': 'transcribe'  # Explicit task
                }
                
                print("🎙️ Sending to Whisper...")
                response = requests.post(WHISPER_URL, files=files, data=data)
                response.raise_for_status()
                
                result = response.json()
                print(f"✅ Whisper response: {result}")
            
            # Extract text and language properly
            text = result.get('text', '').strip()
            language = result.get('language', 'unknown')
            duration = result.get('duration', 0)
            
            response_data = {
                "status": "success",
                "text": text,
                "language": language
            }
            print(f"📤 Sending response: {response_data}")
            print(f"📤 Response type: {type(response_data)}")
            print(f"📤 Text length: {len(text)}")
            
            json_response = jsonify(response_data)
            print(f"📤 JSON response created successfully")
            
            return json_response, 200
            
        finally:
            # Cleanup temp files
            try:
                os.unlink(tmp_input_path)
                os.unlink(tmp_wav_path)
                print("🗑️ Cleaned up temp files")
            except:
                pass
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        print(f"❌ Error type: {type(e)}")
        import traceback
        print(f"❌ Traceback: {traceback.format_exc()}")
        
        error_response = {"error": str(e)}
        print(f"❌ Sending error response: {error_response}")
        return jsonify(error_response), 500

@app.route('/ask-ollama', methods=['POST'])
def ask_ollama():
    """Simple Ollama query endpoint"""
    try:
        data = request.get_json()
        
        if not data or 'prompt' not in data:
            return jsonify({"error": "No prompt provided"}), 400
        
        payload = {
            "model": data.get('model', 'llama3.1:8b'),
            "prompt": data['prompt'],
            "stream": False
        }
        
        response = requests.post(OLLAMA_URL, json=payload)
        response.raise_for_status()
        
        result = response.json()
        
        return jsonify({
            "status": "success",
            "response": result.get('response', '')
        }), 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Quick health check"""
    return jsonify({"status": "ok"}), 200

if __name__ == '__main__':
    print("🎙️ Simple Whisper + Ollama API")
    print("================================")
    print("POST /transcribe   - Upload audio (any format → auto converts to WAV)")
    print("POST /ask-ollama   - Send prompt to Ollama")
    print("GET  /health       - Health check")
    print("\n⚡ No timeouts - will wait as long as needed")
    print("🔧 Requires FFmpeg for audio conversion")
    print("\nRunning on http://localhost:5000")
    
    app.run(host='0.0.0.0', port=5000, debug=True)