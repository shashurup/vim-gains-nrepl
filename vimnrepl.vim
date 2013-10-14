if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

python << EOF

import nrepl

conn = None

def connect(url):
  global conn
  conn = nrepl.connect(url)

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
  for msg in interact({"op": "eval", "code": code}):
    if 'out' in msg:
      print(msg['out'])
    if 'err' in msg:
      print >>sys.stderr, msg['err']
    if 'value' in msg:
      result.append(msg['value'])
  if result:
    return result if len(result) > 1 else result[0]

EOF
