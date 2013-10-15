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

nrepl_conn = None

def connect(url = None):
  global nrepl_conn
  if nrepl_conn:
    nrepl_conn.close()
  if url:
    nrepl_conn = nrepl.connect(url)
  else:
    port = detect_project_repl_port()
    if port:
      connect('nrepl://localhost:%s' % (port))
    else:
      print >>sys.stderr, 'Project repl has not been found, please specify an url'

def interact(msg):
  global nrepl_conn
  if not nrepl_conn:
    connect()
  nrepl_conn.write(msg)
  done = None
  result = []
  while not done:
    msg = nrepl_conn.read()
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
  return result

def print_list(list):
  for item in list:
    print(item)

EOF

function! s:NREval(code) range
python << EOF
import vim
code = vim.eval('a:code')
if code:
  print_list(eval(code))
else:
  first = int(vim.eval('a:firstline'))
  last = int(vim.eval('a:lastline'))
  if first == 1 and last == len(vim.current.buffer):
    print "whole file"
  else:
    print_list(eval('\n'.join(vim.current.buffer[first - 1:last])))
EOF
endfunction

command! -nargs=? -range NREval <line1>,<line2>call s:NREval(<q-args>)
command! NREvalVisual call s:NREval(@*)
