if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif

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
command! -nargs=? NreplCloseSession call NreplCloseSession(<q-args>)
command! -nargs=? -range NreplEval <line1>,<line2>call NreplEval(<q-args>)

" Sample mappings
nmap <silent> ;e [[va(:call NreplEval(@*)<CR>
vnoremap <silent> ;e :call NreplEval(@*)<CR>

nmap <silent> ;d viw:call NreplEval('(doc '.@*.')')<CR>
nmap <silent> ;s viw:call NreplEval('(source '.@*.')')<CR>
nmap <silent> ;m va(:call NreplEval('(macroexpand '''.@*.')')<CR>
vnoremap <silent> ;m :call NreplEval('(macroexpand '''.@*.')')<CR>
