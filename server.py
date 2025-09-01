# server.py - serve index.html and proxy /v1/* to local llama-server
import os, subprocess, threading, time, requests
from flask import Flask, send_from_directory, request, Response

app = Flask(__name__, static_folder='.', static_url_path='')

LLAMA_PORT = int(os.environ.get('LLAMA_PORT', 8081))
MODEL_PATH = '/app/model/SmolVLM-500M-Instruct-GGUF/SmolVLM-500M-Instruct-Q8_0.gguf'
MMPATH = '/app/model/SmolVLM-500M-Instruct-GGUF/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf'

def start_llama():
    cmd = ['llama-server', '-m', MODEL_PATH, '--mmproj', MMPATH,
           '--host', '127.0.0.1', '--port', str(LLAMA_PORT)]
    print('Starting llama-server:', ' '.join(cmd))
    proc = subprocess.Popen(cmd)
    # wait until server responds (or timeout)
    for i in range(60):
        try:
            r = requests.get(f'http://127.0.0.1:{LLAMA_PORT}/')
            print('llama-server is responding')
            break
        except Exception:
            time.sleep(1)
    if proc.poll() is not None:
        print('llama-server exited prematurely')

# Start llama-server in background thread
threading.Thread(target=start_llama, daemon=True).start()

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/v1/<path:path>', methods=['GET','POST','OPTIONS'])
def proxy(path):
    # proxy request to local llama-server
    url = f'http://127.0.0.1:{LLAMA_PORT}/v1/{path}'
    if request.method == 'OPTIONS':
        resp = Response()
        resp.headers['Access-Control-Allow-Origin'] = '*'
        resp.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        return resp
    headers = {k: v for k, v in request.headers.items() if k.lower() != 'host'}
    resp = requests.request(request.method, url, headers=headers,
                            data=request.get_data(), params=request.args, stream=True)
    excluded = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
    response_headers = [(name, value) for (name, value) in resp.headers.items() if name.lower() not in excluded]
    return Response(resp.content, resp.status_code, response_headers)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port)
