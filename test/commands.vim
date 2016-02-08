let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

function! s:suite.internal() abort
  VimShellCreate

  let $FOO = ''
  call vimshell#execute('export FOO=foo')
  call s:assert.equals($FOO, 'foo')

  " It contains space
  let $FOO = ''
  call vimshell#execute('export FOO="foo bar"')
  call s:assert.equals($FOO, 'foo bar')

  let $FOO = ''
  let $BAR = ''
  call vimshell#execute('export FOO="foo" BAR="bar"')
  call s:assert.equals($FOO, 'foo')
  call s:assert.equals($BAR, 'bar')

  " Error pattern
  let $FOO = ''
  let $BAR = ''
  call vimshell#execute('export FOO = "foo" BAR="bar"')
  call s:assert.equals($FOO, '')
  call s:assert.equals($BAR, '')

  VimShellCreate -toggle
endfunction

" vim:foldmethod=marker:fen:
