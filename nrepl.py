import socket

def connect(scheme, host, port):
    s = socket.create_connection((host, port))
    return s.makefile('rw')

def disconnect(connection):
    connection.close()

def perform(request):
    pass

def open_session(connection):
    pass

def clone_session(connection, session):
    pass

def close_session(session):
    pass
