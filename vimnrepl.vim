if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

python << EOF

import nrepl
import os.path

def detect_project_repl_port():
  port_files = ['target/repl-port', 'target/repl/repl-port', '.nrepl-port']
  for pf in port_files:
    if os.path.exists(pf):
      with open(pf, 'r') as f:
        return int(f.read().strip())

conn = None

def connect(url = None):
  global conn
  if url:
    conn = nrepl.connect(url)
  else:
    port = detect_project_repl_port()
    if port:
      connect('nrepl://localhost:%s' % (port))
    else:
      print >>sys.stderr, 'Project repl has not been found, please specify an url'

def interact(msg):
  global conn
  conn.write(msg)
  done = None
  result = []
  while not done:
    msg = conn.read()
    if msg:
      result.append(msg)
      done = 'status' in msg and 'done' in msg['status']
  return result

def eval(code):
  result = []
  for msg in interact({'op': 'eval', 'code': code}):
    if 'out' in msg:
      print(msg['out'])
    if 'err' in msg:
      print >>sys.stderr, msg['err']
    if 'value' in msg:
      result.append(msg['value'])
  if result:
    return result if len(result) > 1 else result[0]

EOF
