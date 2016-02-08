let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

function! s:suite.alias() abort
  VimShellCreate
  call vimshell#set_alias('l2', 'll')
  call vimshell#set_alias('ll', 'ls -l')
  call s:assert.equals(
        \ vimshell#parser#parse_alias('l2'), 'ls -l')
  VimShellCreate -toggle
endfunction

function! s:suite.getopt() abort
  call s:assert.equals(vimshell#parser#getopt(['foo', 'bar'], {
          \ 'noarg' : ['--insert'],
          \ }), [['foo', 'bar'], {}])
endfunction

" vim:foldmethod=marker:fen:
