
"""
    Simple client for nrepl
    based on Chas Emerick's nrepl-python-client
"""

import socket
from cStringIO import StringIO

# this needs to changed for python 3 
text_type = unicode
string_types = (str, unicode)
unichr = unichr

def _read_byte(s):
    return s.read(1)


def _read_int(s, terminator=None, init_data=None):
    int_chrs = init_data or []
    while True:
        c = _read_byte(s)
        if not c.isdigit() or c == terminator or not c:
            break
        else:
            int_chrs.append(c)
    return int(''.join(int_chrs))


def _read_bytes(s, n):
    data = StringIO()
    cnt = 0
    while cnt < n:
        m = s.read(n - cnt)
        if not m:
            raise Exception("Invalid bytestring, unexpected end of input.")
        data.write(m)
        cnt += len(m)
    data.flush()
    # Taking into account that Python3 can't decode strings
    try:
        ret = data.getvalue().decode("UTF-8")
    except AttributeError:
        ret = data.getvalue()
    return ret


def _read_delimiter(s):
    d = _read_byte(s)
    if d.isdigit():
        d = _read_int(s, ":", [d])
    return d


def _read_list(s):
    data = []
    while True:
        datum = _read_datum(s)
        if not datum:
            break
        data.append(datum)
    return data


def _read_map(s):
    i = iter(_read_list(s))
    return dict(zip(i, i))


_read_fns = {"i": _read_int,
             "l": _read_list,
             "d": _read_map,
             "e": lambda _: None,
             # EOF
             None: lambda _: None}


def _read_datum(s):
    delim = _read_delimiter(s)
    if delim:
        return _read_fns.get(delim, lambda s: _read_bytes(s, delim))(s)


def _write_datum(x, out):
    if isinstance(x, string_types):
        # x = x.encode("UTF-8")
        # TODO revisit encodings, this is surely not right. Python
        # (2.x, anyway) conflates bytes and strings, but 3.x does not...
        out.write(str(len(x)))
        out.write(":")
        out.write(x)
    elif isinstance(x, int):
        out.write("i")
        out.write(str(x))
        out.write("e")
    elif isinstance(x, (list, tuple)):
        out.write("l")
        for v in x:
            _write_datum(v, out)
        out.write("e")
    elif isinstance(x, dict):
        out.write("d")
        for k, v in x.items():
            _write_datum(k, out)
            _write_datum(v, out)
        out.write("e")
    out.flush()

def _merge_optional(d, options):
    for k, v in options.iteritems():
        if v:
            d[k] = v

def connect(port, host = 'localhost', scheme = 'nrepl'):
    s = socket.create_connection((host, port))
    return s.makefile('rw')

def disconnect(connection):
    connection.close()

def send(connection, request):
    _write_datum(request, connection)
    done = None
    result = []
    while not done:
        msg = _read_datum(connection)
        result.append(msg)
        status = msg.get('status')
        if status:
            done = 'done' in status or 'error' in status
    return result

def open_session(connection):
    return clone_session(connection, None)

def clone_session(connection, session):
    request = {'op': 'clone'}
    _merge_optional(request, {'session': session})
    for msg in send(connection, request):
        if 'new-session' in msg:
            return msg['new-session']
    

def close_session(connection, session):
    return send(connection, {'op': 'close', 'session': session})

def eval(connection, code, session=None, path=None, line=None):
    request = {'op': 'eval', 'code': code}
    _merge_optional(request, {'session': session, 'file': path, 'line': line})
    return send(connection, request)

def load_file(connection, content, path=None, name=None, session=None):
    request = {'op': 'load-file', 'file': content}
    _merge_optional(request, {'session': session, 'file-path': path, 'file-name': name})
    return send(connection, request)
