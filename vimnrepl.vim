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
nrepl_ns = None

def connect(url = None):
  global nrepl_conn, nrepl_ns
  if nrepl_conn:
    nrepl_conn.close()
  nrepl_ns = None
  if url:
    nrepl_conn = nrepl.connect(url)
  else:
    port = detect_project_repl_port()
    if port:
      connect('nrepl://localhost:%s' % (port))
    else:
      print >>sys.stderr, 'Project repl has not been found, please specify an url'

def disconnect():
  global nrepl_conn
  if nrepl_conn:
    nrepl_conn.close()
    nrepl_conn = None

def interact(msg):
  global nrepl_conn, nrepl_ns
  if not nrepl_conn:
    connect()
  if nrepl_ns:
    msg['ns'] = nrepl_ns
  nrepl_conn.write(msg)
  done = None
  result = []
  while not done:
    msg = nrepl_conn.read()
    if msg:
      result.append(msg)
      done = 'status' in msg and 'done' in msg['status']
  return result

def handle_response(response):
  result = []
  global nrepl_ns
  for msg in response:
    if 'ns' in msg:
      nrepl_ns = msg['ns']
    if 'out' in msg:
      print(msg['out'])
    if 'err' in msg:
      print >>sys.stderr, msg['err']
    if 'value' in msg:
      result.append(msg['value'])
  return result

def eval(code):
  return handle_response(interact({'op': 'eval', 'code': code}))

def load(file, name = None, path = None):
  msg = {'op': 'load-file', 'file': file}
  if name:
    msg['file-name'] = name
  if path:
    msg['file-path'] = path
  return handle_response(interact(msg))

def print_list(list):
  for item in list:
    print(item)

EOF

function! NreplEval(code) range
python << EOF
import vim
code = vim.eval('a:code')
if code:
  print_list(eval(code))
else:
  first = int(vim.eval('a:firstline'))
  last = int(vim.eval('a:lastline'))
  if first == 1 and last == len(vim.current.buffer):
    name = vim.eval("expand('%:t')")
    path = vim.eval("expand('%:p')")
    print_list(load('\n'.join(vim.current.buffer[:]), name, path))
  else:
    print_list(eval('\n'.join(vim.current.buffer[first - 1:last])))
EOF
endfunction

command! -nargs=? NreplConnect py connect(<q-args>)
command! NreplDisconnect py disconnect()
command! -nargs=? -range NreplEval <line1>,<line2>call NreplEval(<q-args>)

" Sample mappings
nmap <silent> ;e [[va(:call NreplEval(@*)<CR>
vnoremap <silent> ;e :call NreplEval(@*)<CR>

nmap <silent> ;d viw:call NreplEval('(doc '.@*.')')<CR>
nmap <silent> ;s viw:call NreplEval('(source '.@*.')')<CR>
nmap <silent> ;m va(:call NreplEval('(macroexpand '''.@*.')')<CR>
vnoremap <silent> ;m :call NreplEval('(macroexpand '''.@*.')')<CR>
