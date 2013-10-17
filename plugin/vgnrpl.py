import vim
import sys
import os.path
import nrepl
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
            yield join_session_url((scheme, host, port, session))

def get_buffer_map():
    result = {}
    for buf in vim.buffers:
        session_url = buf.vars.get('nrepl_session_url')
        if session_url:
            result.setdefault(session_url, []).append(buf.name)
    return result

def create_session(scheme, host, port):
    conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
    if not conn:
        conn = nrepl.connect(port, host, scheme)
        sess_list = set()
        nrepl_connections[(scheme, host, port)] = (conn, sess_list)
    session = nrepl.open_session(conn)
    sess_list.add(session)
    return conn, session

def project_repl():
    port = detect_project_repl_port()
    if port:
        conn, session = create_session('repl', 'localhost', port)
        return conn, session, join_session_url(('repl', 'localhost', port, session))
    return None, None, None

def find_session(url):
    scheme, host, port, session = split_session_url(url)
    conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
    if conn and session in sess_list:
        return conn, session
    return None, None

def session_exists(scheme, host, port, session):
    conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
    return conn and session in sess_list

def close_session(url):
    scheme, host, port, session = split_session_url(url)
    if session:
        conn, sess_list = nrepl_connections.get((scheme, host, port), (None, None))
        if conn:
            nrepl.close_session(conn, session)
            sess_list.remove(session)
            if not len(sess_list):
                nrepl.disconnect(conn)
                del nrepl_connections[(scheme, host, port)]

def print_response(response):
    for msg in response:
        if 'out' in msg:
            print msg['out']
        if 'err' in msg:
            print >>sys.stderr, msg['err']
        if 'value' in msg:
            print msg['value']

def set_buffer_session(url):
    if url:
        scheme, host, port, session = split_session_url(url)
        if session:
            if not session_exists(scheme, host, port, session):
                print >>sys.stderr, 'Session %s does not exist' % (url)
                return
        else:
            c, session = create_session(scheme, host, port)
        vim.current.buffer.vars['nrepl_session_url'] = join_session_url((scheme, host, port, session))
    print vim.current.buffer.vars.get('nrepl_session_url')

def print_sessions():
    buf_map = get_buffer_map()
    for session_url in get_sessions(nrepl_connections):
        buf_names = buf_map.get(session_url, [])
        print session_url, ', '.join(buf_names)

def collect_garbage():
    buf_map = get_buffer_map()
    for session_url in list(get_sessions(nrepl_connections)):
        if not session_url in buf_map:
            close_session(session_url)
            print 'Closed', session_url

def clear_buffer_session():
    url = vim.current.buffer.vars.get('nrepl_session_url')
    if url:
        del vim.current.buffer.vars['nrepl_session_url']
        collect_garbage()

def eval(code, first, last):
    conn, session = None, None
    session_url = vim.current.buffer.vars.get('nrepl_session_url')
    if not session_url:
        conn, session, session_url = project_repl()
        if conn:
            vim.current.buffer.vars['nrepl_session_url'] = session_url
        else:
            print >>sys.stderr, 'Project repl has not been found'
    else:
        conn, session = find_session(session_url)
        if not conn:
            print >>sys.stderr, 'Session %s does not exist' % (session_url)
    if conn:
        if code:
            print_response(nrepl.eval(conn, code, session))
        else:
            if first == 1 and last == len(vim.current.buffer):
                name = vim.eval("expand('%:t')")
                path = vim.eval("expand('%:p')")
                code = '\n'.join(vim.current.buffer[:])
                print_response(nrepl.load_file(conn, code, path, name, session))
            else:
                code = '\n'.join(vim.current.buffer[first - 1:last])
                print_response(nrepl.eval(conn, code, session))
