if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

python << EOF

import nrepl
import os.path
from urlparse import urlparse

nrepl_connections = {}

def detect_project_repl_port():
    port_files = ['target/repl-port', 'target/repl/repl-port', '.nrepl-port']
    for pf in port_files:
        if os.path.exists(pf):
            with open(pf, 'r') as f:
                return int(f.read().strip())

def split_session_url(url):
    components = urlparse(url)
    host_port = components.netloc.split(':')
    if len(host_port) < 2:
        raise Exception('%s does not contain port number' % (url))
    return components.scheme, host_port[0], int(host_port[1]), components.path[1:]

def join_session_url(components):
    return "%s://%s:%s/%s" % components

def get_sessions(connections):
    for (scheme, host, port), (conn, sess_list) in connections.iteritems():
        for session in sess_list:
            yield (scheme, host, port, session)

def create_session(scheme, host, port):
    conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
    if not conn:
        conn = nrepl.connect(port, host, scheme)
        sess_list = set()
        nrepl_connections[(scheme, host, port)] = (conn, sess_list)
    session = nrepl.open_session(conn)
    sess_list.add(session)
    return conn, session

def find_connection(scheme, host, port, session):
    conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
    if conn and session in sess_list:
        return conn

def assign_session_to_current_buffer(session_url):
    scheme, host, port, session = split_session_url(session_url)
    if session:
        if not find_connection(scheme, host, port, session):
            raise Exception('session %s is not found' % (session_url))
    else:
        conn, session = create_session(scheme, host, port)
    vim.current.buffer.vars['nrepl_session_url'] = join_session_url((scheme, host, port, session))
    return conn, session

def get_or_create_current_buffer_session():
    session_url = vim.current.buffer.vars.get('nrepl_session_url')
    if session_url:
        scheme, host, port, session = split_session_url(session_url)
        conn = find_connection(scheme, host, port, session)
        if not conn:
            raise Exception('session %s is not found' % (session_url))
        return conn, session
    port = detect_project_repl_port()
    if not port:
        print >>sys.stderr, 'Project repl has not been found'
    return assign_session_to_current_buffer("nrepl://localhost:%s" % (port))

def print_response(response):
  for msg in response:
    if 'out' in msg:
      print msg['out']
    if 'err' in msg:
      print >>sys.stderr, msg['err']
    if 'value' in msg:
      print msg['value']

EOF

function! NreplSession(url)
python << EOF
import vim
session_url = vim.eval('a:url')
if session_url:
    assign_session_to_current_buffer(session_url)
print vim.current.buffer.vars.get('nrepl_session_url')
EOF
endfunction

function! NreplListSessions()
python << EOF
for session_url in map(join_session_url, get_sessions(nrepl_connections)):
    print session_url
EOF
endfunction

function! NreplEval(code) range
python << EOF
import vim
code = vim.eval('a:code')
conn, session = get_or_create_current_buffer_session()
if code:
    print_response(nrepl.eval(conn, code, session))
else:
    first = int(vim.eval('a:firstline'))
    last = int(vim.eval('a:lastline'))
    if first == 1 and last == len(vim.current.buffer):
        name = vim.eval("expand('%:t')")
        path = vim.eval("expand('%:p')")
        code = '\n'.join(vim.current.buffer[:])
        print_response(nrepl.load_file(conn, code, path, name, session))
    else:
        code = '\n'.join(vim.current.buffer[first - 1:last])
        print_response(nrepl.eval(conn, code, session))
EOF
endfunction

command! -nargs=? NreplSession call NreplSession(<q-args>)
command! NreplListSessions call NreplListSessions()
command! -nargs=? -range NreplEval <line1>,<line2>call NreplEval(<q-args>)

" Sample mappings
nmap <silent> ;e [[va(:call NreplEval(@*)<CR>
vnoremap <silent> ;e :call NreplEval(@*)<CR>

nmap <silent> ;d viw:call NreplEval('(doc '.@*.')')<CR>
nmap <silent> ;s viw:call NreplEval('(source '.@*.')')<CR>
nmap <silent> ;m va(:call NreplEval('(macroexpand '''.@*.')')<CR>
vnoremap <silent> ;m :call NreplEval('(macroexpand '''.@*.')')<CR>
