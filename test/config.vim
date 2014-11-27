let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

function! s:suite.prompt()
  let g:vimshell_prompt = "'% ' "
  let g:vimshell_secondary_prompt = 'aaa '
  VimShellCreate -toggle
  call s:assert.equals(vimshell#get_prompt(), "'% ' ")
  call s:assert.equals(vimshell#get_secondary_prompt(), 'aaa ')
  VimShellCreate -toggle

  let g:vimshell_user_prompt = 'fnamemodify(getcwd(), ":~")'
  VimShellCreate -toggle
  call s:assert.equals(vimshell#get_user_prompt(),
        \ 'fnamemodify(getcwd(), ":~")')
  VimShellCreate -toggle
  let g:vimshell_user_prompt = ""
endfunction

function! s:suite.options()
  VimShellCreate -toggle -prompt=foo\ bar
  call s:assert.equals(vimshell#get_prompt(), 'foo bar')
  VimShellCreate -toggle
endfunction

" vim:foldmethod=marker:fen:
