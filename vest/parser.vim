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
    ShouldEqual vimshell#parser#parse_alias('l2'), 'ls -l'
    VimShellCreate -toggle
  End

  It tests option parser.
    ShouldEqual vimshell#parser#getopt(['foo', 'bar'], {
          \ 'noarg' : ['--insert'],
          \ }), [['foo', 'bar'], {}]
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
