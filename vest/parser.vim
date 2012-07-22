" Tests for vimshell.

scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context Vesting.run()
  It tests aliases.
    VimShellCreate
    call vimshell#set_alias('l2', 'll')
    call vimshell#set_alias('ll', 'ls -l')
    Should vimshell#parser#parse_alias('l2') ==# 'ls -l'
    VimShellCreate -toggle
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
