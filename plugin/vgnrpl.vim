" Vim global plugin for nrepl integration
" Maintainer: Georgy Kibardin <george-kibardin@yandex.ru>
" License: MIT

if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

if exists('g:vgnrpl_loaded')
  finish
endif
let g:vgnrpl_loaded = 1

python << EOF
import vim
sys.path.append(vim.eval("expand('<sfile>:p:h')"))
import vgnrpl
EOF

function! NreplSession(url)
python << EOF
vgnrpl.set_buffer_session(vim.eval('a:url'))
EOF
endfunction

function! NreplListSessions()
python << EOF
vgnrpl.print_sessions()
EOF
endfunction

function! NreplClearSession(buf)
python << EOF
vgnrpl.clear_buffer_session(vim.eval('a:buf'))
EOF
endfunction

function! NreplCloseSession(url)
python << EOF
vgnrpl.close_buffer_session(vim.eval('a:url'))
EOF
endfunction

function! NreplCollectGarbage()
python << EOF
vgnrpl.collect_garbage()
EOF
endfunction

function! NreplEval(code) range
python << EOF
vgnrpl.eval(vim.eval('a:code'), int(vim.eval('a:firstline')), int(vim.eval('a:lastline')))
EOF
endfunction

command! -nargs=? NreplSession call NreplSession(<q-args>)
command! NreplListSessions call NreplListSessions()
command! -nargs=? NreplClearSession call NreplClearSession(<q-args>)
command! -nargs=? -range NreplEval <line1>,<line2>call NreplEval(<q-args>)
